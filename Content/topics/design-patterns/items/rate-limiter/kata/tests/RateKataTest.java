import java.util.List;
import java.util.concurrent.atomic.AtomicLong;
import kata.*;

class RateKataTest {
    final AtomicLong clock = new AtomicLong();

    void atMs(long ms) { clock.set(ms * 1_000_000); }

    TokenBucket bucket() { return new TokenBucket(3, 2, clock::get); }

    @Check(id = "burst-up-to-capacity")
    void burstUpToCapacity() {
        TokenBucket b = bucket();
        for (int i = 1; i <= 3; i++) {
            Expect.equal(0L, b.acquire(), "request " + i + " of the initial burst");
        }
        Expect.isTrue(b.acquire() > 0, "the 4th request should be rejected");
    }

    @Check(id = "retry-after-in-ms")
    void retryAfterInMs() {
        TokenBucket b = bucket();
        for (int i = 0; i < 3; i++) b.acquire();
        Expect.equal(500L, b.acquire(), "retry-after right after the burst (2 tokens/s)");
        atMs(100);
        Expect.equal(400L, b.acquire(), "retry-after 100 ms later");
    }

    @Check(id = "refills-with-time")
    void refillsWithTime() {
        TokenBucket b = bucket();
        for (int i = 0; i < 3; i++) b.acquire();
        atMs(499);
        Expect.isTrue(b.acquire() > 0, "no token after 499 ms");
        atMs(500);
        Expect.equal(0L, b.acquire(), "one token after 500 ms");
        Expect.isTrue(b.acquire() > 0, "only one token was earned");
    }

    @Check(id = "never-above-capacity")
    void neverAboveCapacity() {
        TokenBucket b = bucket();
        for (int i = 0; i < 3; i++) b.acquire();
        atMs(60_000);
        for (int i = 1; i <= 3; i++) {
            Expect.equal(0L, b.acquire(), "request " + i + " after a long idle");
        }
        Expect.isTrue(b.acquire() > 0, "idle time must not bank more than capacity");
    }

    @Check(id = "rejections-cost-nothing")
    void rejectionsCostNothing() {
        TokenBucket b = bucket();
        for (int i = 0; i < 3; i++) b.acquire();
        for (int i = 0; i < 20; i++) b.acquire();
        atMs(500);
        Expect.equal(0L, b.acquire(), "rejected requests must not delay the refill");
        for (long t = 600; t < 1000; t += 100) {
            atMs(t);
            Expect.isTrue(b.acquire() > 0, "a retry at " + t + " ms (polling every "
                + "100 ms must not count the same elapsed time twice)");
        }
        atMs(1000);
        Expect.equal(0L, b.acquire(), "the next token at 1000 ms");
    }

    @Check(id = "retry-after-is-honest")
    void retryAfterIsHonest() {
        TokenBucket b = new TokenBucket(1, 3, clock::get);
        Expect.equal(0L, b.acquire(), "the only token");
        long wait = b.acquire();
        Expect.equal(334L, wait, "retry-after at 3 tokens/s, rounded up");
        atMs(wait);
        Expect.equal(0L, b.acquire(), "a request after waiting the advertised time");
    }

    @Check(id = "clients-have-separate-buckets")
    void clientsHaveSeparateBuckets() {
        Limiter limiter = new Limiter(3, 2, clock::get);
        for (int i = 0; i < 3; i++) {
            Expect.equal(0L, limiter.acquire("a"), "client a, request " + (i + 1));
        }
        Expect.equal(500L, limiter.acquire("a"), "client a past its burst");
        Expect.equal(0L, limiter.acquire("b"), "client b is unaffected by a");
        atMs(500);
        Expect.equal(0L, limiter.acquire("a"), "client a after refill");
    }

    @Check(id = "racing-callers-share-the-burst")
    void racingCallersShareTheBurst() {
        Limiter limiter = new Limiter(5, 1, clock::get);
        List<Long> results = Stress.race(16, () -> limiter.acquire("shared"));
        long admitted = results.stream().filter(r -> r == 0).count();
        Expect.equal(5L, admitted, "requests admitted from a capacity-5 bucket");
    }

    @Check(id = "time-is-injected", kind = Kind.DESIGN)
    void timeIsInjected() {
        for (String type : List.of("TokenBucket", "Limiter")) {
            var shape = Source.type(type);
            Expect.none(shape.calls("nanoTime"), type + " reads the system clock");
            Expect.none(shape.calls("currentTimeMillis"), type + " reads the system clock");
            Expect.none(shape.calls("now"), type + " reads the system clock");
            Expect.none(shape.calls("sleep"), type + " must reject, never sleep");
        }
    }
}
