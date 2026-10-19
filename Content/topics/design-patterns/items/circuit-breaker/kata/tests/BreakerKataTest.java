import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;
import java.util.function.Supplier;
import kata.*;

class BreakerKataTest {
    final AtomicLong now = new AtomicLong();
    final AtomicInteger calls = new AtomicInteger();
    final CircuitBreaker breaker = new CircuitBreaker(3, 1000, now::get);

    Supplier<String> failing() {
        return () -> {
            calls.incrementAndGet();
            throw new IllegalStateException("down");
        };
    }

    Supplier<String> working() {
        return () -> {
            calls.incrementAndGet();
            return "live";
        };
    }

    String fail() { return breaker.call(failing(), () -> "cached"); }

    void trip() {
        for (int i = 0; i < 3; i++) fail();
    }

    @Check(id = "closed-passes-through")
    void closedPassesThrough() {
        Expect.equal("live", breaker.call(working(), () -> "cached"), "a healthy call");
        Expect.equal(State.CLOSED, breaker.state(), "state after success");
    }

    @Check(id = "opens-after-threshold")
    void opensAfterThreshold() {
        Expect.equal("cached", fail(), "a failing call returns the fallback");
        fail();
        Expect.equal(State.CLOSED, breaker.state(), "state after 2 failures");
        fail();
        Expect.equal(State.OPEN, breaker.state(), "state after 3 failures");
        Expect.equal(3, calls.get(), "calls to the operation");
    }

    @Check(id = "open-rejects-without-calling")
    void openRejectsWithoutCalling() {
        trip();
        now.set(999);
        Expect.equal("cached", breaker.call(working(), () -> "cached"),
            "a call while open");
        Expect.equal(3, calls.get(), "the operation must not run while open");
        Expect.equal(State.OPEN, breaker.state(), "state just before the cool-down ends");
    }

    @Check(id = "success-resets-failure-count")
    void successResetsFailureCount() {
        fail();
        fail();
        breaker.call(working(), () -> "cached");
        fail();
        fail();
        Expect.equal(State.CLOSED, breaker.state(),
            "state after fail, fail, success, fail, fail (only consecutive failures count)");
    }

    @Check(id = "half-open-after-cooldown")
    void halfOpenAfterCooldown() {
        trip();
        now.set(1000);
        State[] seen = new State[1];
        breaker.call(() -> {
            seen[0] = breaker.state();
            return "live";
        }, () -> "cached");
        Expect.equal(State.HALF_OPEN, seen[0], "state while the probe runs");
        Expect.equal(State.CLOSED, breaker.state(), "state after a successful probe");
    }

    @Check(id = "probe-failure-reopens")
    void probeFailureReopens() {
        trip();
        now.set(1000);
        Expect.equal("cached", fail(), "a failing probe returns the fallback");
        Expect.equal(State.OPEN, breaker.state(), "state after a failed probe");
        int before = calls.get();
        now.set(1999);
        breaker.call(working(), () -> "cached");
        Expect.equal(before, calls.get(),
            "the cool-down restarts from the failed probe");
        now.set(2000);
        Expect.equal("live", breaker.call(working(), () -> "cached"),
            "the next probe after a second cool-down");
    }

    @Check(id = "only-one-probe-at-a-time")
    void onlyOneProbeAtATime() {
        trip();
        now.set(1000);
        AtomicInteger inner = new AtomicInteger();
        String outer = breaker.call(() -> {
            breaker.call(() -> {
                inner.incrementAndGet();
                return "live";
            }, () -> "cached");
            return "live";
        }, () -> "cached");
        Expect.equal("live", outer, "the probe");
        Expect.equal(0, inner.get(),
            "a call made while the probe is in flight must get the fallback");
    }

    @Check(id = "racing-callers-share-one-probe", timeoutMs = 4000)
    void racingCallersShareOneProbe() {
        trip();
        int before = calls.get();
        now.set(1000);
        Stress.race(8, () -> breaker.call(failing(), () -> "cached"));
        Expect.equal(before + 1, calls.get(),
            "operation calls after the cool-down (exactly one probe)");
    }

    @Check(id = "slow-call-does-not-block-others", timeoutMs = 4000)
    void slowCallDoesNotBlockOthers() throws Exception {
        CountDownLatch entered = new CountDownLatch(1);
        CountDownLatch release = new CountDownLatch(1);
        Thread slow = new Thread(() -> breaker.call(() -> {
            entered.countDown();
            try {
                release.await();
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
            return "live";
        }, () -> "cached"));
        slow.setDaemon(true);
        slow.start();
        try {
            Expect.isTrue(entered.await(2, TimeUnit.SECONDS), "the slow call never started");
            Expect.equal(State.CLOSED,
                Expect.completesWithin(1000, breaker::state, "state() during a slow call"),
                "state during a slow call");
        } finally {
            release.countDown();
            slow.join(1000);
        }
    }

    @Check(id = "injected-clock-only", kind = Kind.DESIGN)
    void injectedClockOnly() {
        var breaker = Source.type("CircuitBreaker");
        Expect.none(breaker.calls("currentTimeMillis"), "CircuitBreaker reads the system clock");
        Expect.none(breaker.calls("nanoTime"), "CircuitBreaker reads the system clock");
        Expect.none(breaker.calls("now"), "CircuitBreaker reads the system clock");
        Expect.none(breaker.calls("sleep"), "CircuitBreaker must never sleep");
    }
}
