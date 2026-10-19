import java.util.ArrayDeque;
import java.util.Queue;
import java.util.Set;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.Executor;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import kata.*;

class FuturePromiseKataTest {
    static final Set<String> BLOCKING = Set.of("get", "join", "getNow",
        "resultNow", "await");
    static final Set<String> COMPOSING = Set.of("thenCompose", "thenApply",
        "thenCombine", "handle", "exceptionally", "whenComplete",
        "thenAccept", "thenRun", "thenComposeAsync", "thenApplyAsync",
        "thenCombineAsync", "handleAsync", "exceptionallyCompose", "allOf",
        "anyOf", "applyToEither");

    static ExecutorService pool(int threads) {
        return Executors.newFixedThreadPool(threads, r -> {
            Thread t = new Thread(r, "kata-io");
            t.setDaemon(true);
            return t;
        });
    }

    static <T> T await(CompletableFuture<T> future, String what)
            throws Throwable {
        try {
            return future.get(2, TimeUnit.SECONDS);
        } catch (java.util.concurrent.TimeoutException e) {
            throw new CheckFailure(what + " did not complete within 2000 ms");
        } catch (ExecutionException e) {
            throw e.getCause();
        }
    }

    static Throwable root(Throwable t) {
        while (t.getCause() != null) {
            t = t.getCause();
        }
        return t;
    }

    @Check(id = "summary-chains-both-lookups", timeoutMs = 4000)
    void summaryChainsBothLookups() throws Throwable {
        Billing billing = new Billing(pool(4));
        Expect.equal("user-7 owes 36", await(billing.summary(7), "summary(7)"),
            "summary(7)");
    }

    @Check(id = "pair-joins-two-lookups", timeoutMs = 4000)
    void pairJoinsTwoLookups() throws Throwable {
        Billing billing = new Billing(pool(4));
        Expect.equal("user-3+user-4", await(billing.pair(3, 4), "pair(3, 4)"),
            "pair(3, 4)");
    }

    @Check(id = "failure-reaches-the-caller", timeoutMs = 4000)
    void failureReachesTheCaller() throws Throwable {
        Billing billing = new Billing(pool(4));
        Throwable error = Expect.raises(Throwable.class,
            () -> await(billing.summary(0), "summary(0)"), "summary(0)");
        Throwable cause = root(error);
        Expect.isTrue(cause instanceof IllegalArgumentException
                && "no user 0".equals(cause.getMessage()),
            "summary(0) should fail with the lookup's "
            + "IllegalArgumentException(\"no user 0\"), not " + cause);
    }

    @Check(id = "fallback-replaces-failure", timeoutMs = 4000)
    void fallbackReplacesFailure() throws Throwable {
        Billing billing = new Billing(pool(4));
        Expect.equal("fallback: no user 0",
            await(billing.summaryOrFallback(0), "summaryOrFallback(0)"),
            "summaryOrFallback(0)");
        Expect.equal("user-2 owes 36",
            await(billing.summaryOrFallback(2), "summaryOrFallback(2)"),
            "summaryOrFallback(2)");
    }

    @Check(id = "no-blocking-calls", kind = Kind.DESIGN)
    void noBlockingCalls() {
        var billing = Source.type("Billing");
        for (String name : new String[] {"summary", "pair",
                "summaryOrFallback"}) {
            var method = billing.method(name);
            for (String call : BLOCKING) {
                Expect.none(method.calls(call), "Billing." + name
                    + " blocks a thread with " + call + "()");
            }
        }
    }

    @Check(id = "stages-are-composed", kind = Kind.DESIGN)
    void stagesAreComposed() {
        var billing = Source.type("Billing");
        for (String name : new String[] {"summary", "pair",
                "summaryOrFallback"}) {
            var method = billing.method(name);
            boolean composed = COMPOSING.stream()
                .anyMatch(c -> !method.calls(c).isEmpty());
            Expect.isTrue(composed, "Billing." + name + " should be built "
                + "from the futures with thenCompose, thenCombine, "
                + "thenApply or exceptionally");
        }
    }

    @Check(id = "single-thread-pool-does-not-starve", kind = Kind.DESIGN,
        timeoutMs = 4000)
    void singleThreadPoolDoesNotStarve() throws Throwable {
        Billing billing = new Billing(pool(1));
        Expect.equal("user-7 owes 36",
            await(billing.summary(7), "summary(7) on one I/O thread"),
            "summary(7) on one I/O thread");
        Expect.equal("user-1+user-2",
            await(billing.pair(1, 2), "pair(1, 2) on one I/O thread"),
            "pair(1, 2) on one I/O thread");
    }

    @Check(id = "independent-lookups-start-together", kind = Kind.DESIGN)
    void independentLookupsStartTogether() {
        Queue<Runnable> submitted = new ArrayDeque<>();
        Executor manual = submitted::add;
        Billing billing = new Billing(manual);
        billing.pair(3, 4);
        Expect.equal(2, submitted.size(),
            "lookups submitted before any of them has run");
    }
}
