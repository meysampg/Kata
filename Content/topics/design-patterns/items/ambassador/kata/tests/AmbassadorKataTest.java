import java.io.IOException;
import java.io.InterruptedIOException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import kata.*;

class AmbassadorKataTest {
    /** Fails the first {@code failures} calls, then answers name:key. */
    static final class Node implements KeyValue {
        final String name;
        final int failures;
        final List<String> trace;
        final AtomicInteger calls = new AtomicInteger();

        Node(String name, int failures, List<String> trace) {
            this.name = name;
            this.failures = failures;
            this.trace = trace;
        }

        public String get(String key) throws IOException {
            trace.add(name);
            if (calls.incrementAndGet() <= failures) throw new IOException(name + " is down");
            return name + ":" + key;
        }
    }

    static List<String> trace() {
        return Collections.synchronizedList(new ArrayList<>());
    }

    static String keyForShard(int shard, int shards) {
        for (int i = 0; ; i++) {
            if (Math.floorMod(("k" + i).hashCode(), shards) == shard) return "k" + i;
        }
    }

    @Check(id = "routes-by-key-hash")
    void routesByHash() throws Exception {
        List<String> t = trace();
        var amb = new Ambassador(List.of(
            List.of(new Node("a", 0, t)), List.of(new Node("b", 0, t))), 1, 500);
        Expect.equal("a:" + keyForShard(0, 2), amb.get(keyForShard(0, 2)), "a key of shard 0");
        Expect.equal("b:" + keyForShard(1, 2), amb.get(keyForShard(1, 2)), "a key of shard 1");
    }

    @Check(id = "success-calls-once")
    void successCallsOnce() throws Exception {
        List<String> t = trace();
        var amb = new Ambassador(List.of(List.of(new Node("a", 0, t), new Node("b", 0, t))), 3, 500);
        amb.get("x");
        Expect.equal(List.of("a"), t, "replicas called on a healthy store");
    }

    @Check(id = "retries-same-replica")
    void retriesSameReplica() throws Exception {
        List<String> t = trace();
        var amb = new Ambassador(List.of(List.of(new Node("a", 2, t), new Node("b", 0, t))), 3, 500);
        Expect.equal("a:x", amb.get("x"), "the answer after two transient failures");
        Expect.equal(List.of("a", "a", "a"), t, "calls made");
    }

    @Check(id = "fails-over-after-attempts")
    void failsOver() throws Exception {
        List<String> t = trace();
        var amb = new Ambassador(List.of(List.of(new Node("a", 99, t), new Node("b", 0, t))), 2, 500);
        Expect.equal("b:x", amb.get("x"), "the answer from the second replica");
        Expect.equal(List.of("a", "a", "b"), t, "calls made");
    }

    @Check(id = "gives-up-with-cause")
    void givesUp() {
        List<String> t = trace();
        String key = keyForShard(1, 2);
        var amb = new Ambassador(List.of(List.of(new Node("z", 0, t)),
            List.of(new Node("a", 99, t), new Node("b", 99, t))), 2, 500);
        IOException e = Expect.raises(IOException.class, () -> amb.get(key), "a shard that is fully down");
        Expect.isTrue(e.getMessage() != null && e.getMessage().contains("shard 1 unavailable"),
            "The message should name the shard: shard 1 unavailable, got " + e.getMessage());
        Expect.isTrue(e.getCause() instanceof IOException, "The last failure should be the cause");
        Expect.equal(List.of("a", "a", "b", "b"), t, "calls made");
    }

    @Check(id = "bugs-are-not-retried")
    void bugsNotRetried() {
        List<String> t = trace();
        KeyValue buggy = k -> {
            t.add("bug");
            throw new IllegalStateException("npe-ish");
        };
        var amb = new Ambassador(List.of(List.of(buggy, new Node("b", 0, t))), 3, 500);
        Expect.raises(IllegalStateException.class, () -> amb.get("x"), "a RuntimeException from a replica");
        Expect.equal(List.of("bug"), t, "calls made");
    }

    @Check(id = "timeout-fails-over")
    void timeoutFailsOver() throws Exception {
        CountDownLatch never = new CountDownLatch(1);
        CountDownLatch interrupted = new CountDownLatch(1);
        List<String> t = trace();
        KeyValue hung = k -> {
            t.add("hung");
            try {
                never.await();
            } catch (InterruptedException e) {
                interrupted.countDown();
                throw new InterruptedIOException("cancelled");
            }
            return "late";
        };
        // 200 ms: long enough that the healthy replica never times out,
        // short enough to keep the check quick.
        var amb = new Ambassador(List.of(List.of(hung, new Node("b", 0, t))), 1, 200);
        try {
            String answer = Expect.completesWithin(1200, () -> amb.get("x"),
                "a call to a replica that hangs forever (timeout 200 ms)");
            Expect.equal("b:x", answer, "the answer from the healthy replica");
            Expect.equal(List.of("hung", "b"), t, "calls made");
            Expect.isTrue(interrupted.await(500, TimeUnit.MILLISECONDS),
                "The timed-out try should be cancelled with an interrupt, not left "
                    + "hanging (a CompletableFuture's cancel never interrupts)");
        } finally {
            never.countDown();
        }
    }

    @Check(id = "profile-service-unchanged")
    void profileServiceUnchanged() throws Exception {
        List<String> t = trace();
        var amb = new Ambassador(List.of(List.of(new Node("a", 1, t), new Node("b", 0, t))), 1, 500);
        Expect.equal("b:user:7", new ProfileService(amb).load("7"), "ProfileService.load through the ambassador");
    }

    @Check(id = "ambassador-is-a-keyvalue", kind = Kind.DESIGN)
    void isAKeyValue() {
        Expect.isTrue(KeyValue.class.isAssignableFrom(Types.named("Ambassador")),
            "Ambassador should implement KeyValue so the application cannot tell it apart");
    }

    @Check(id = "application-stays-unaware", kind = Kind.DESIGN)
    void appUnaware() {
        var app = Source.type("ProfileService");
        Expect.none(app.mentions("Ambassador"), "ProfileService names the Ambassador");
        Expect.none(app.calls("sleep"), "ProfileService retries itself");
        Expect.none(app.news("Ambassador"), "ProfileService builds its own proxy");
    }

    @Check(id = "no-sleeping-retry", kind = Kind.DESIGN)
    void noSleep() {
        Expect.none(Source.type("Ambassador").calls("sleep"),
            "Ambassador sleeps between tries; retry immediately, the tests have no time to waste");
    }
}
