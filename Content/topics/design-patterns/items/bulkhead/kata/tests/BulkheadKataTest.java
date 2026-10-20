import java.lang.reflect.Field;
import java.lang.reflect.Modifier;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;
import java.util.function.Supplier;
import kata.*;

class BulkheadKataTest {
    final CountDownLatch release = new CountDownLatch(1);
    final List<Thread> holders = new ArrayList<>();

    /** Starts calls that stay inside the bulkhead until release is counted down. */
    void occupy(Bulkhead b, int n) throws InterruptedException {
        CountDownLatch entered = new CountDownLatch(n);
        AtomicReference<Throwable> crashed = new AtomicReference<>();
        for (int i = 0; i < n; i++) {
            Thread t = new Thread(() -> b.call(() -> {
                entered.countDown();
                try {
                    release.await();
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                }
                return "done";
            }), "kata-holder");
            t.setDaemon(true);
            t.setUncaughtExceptionHandler((th, e) -> crashed.set(e));
            holders.add(t);
            t.start();
        }
        long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(1);
        while (!entered.await(5, TimeUnit.MILLISECONDS)) {
            if (crashed.get() != null || System.nanoTime() > deadline) {
                Expect.fail(n + " calls within the limit should all be inside at once"
                    + (crashed.get() == null ? "" : "; one threw " + crashed.get()));
            }
        }
    }

    void drain() throws InterruptedException {
        release.countDown();
        for (Thread t : holders) t.join(1000);
    }

    @Check(id = "runs-under-the-limit")
    void runsUnderTheLimit() {
        Bulkhead b = new Bulkhead("inventory", 2);
        Expect.equal("ok", b.call(() -> "ok"), "a call under the limit");
    }

    @Check(id = "rejects-when-full")
    void rejectsWhenFull() throws Exception {
        Bulkhead b = new Bulkhead("inventory", 2);
        occupy(b, 2);
        try {
            AtomicInteger ran = new AtomicInteger();
            BulkheadFullException e = Expect.raises(BulkheadFullException.class,
                () -> b.call(() -> ran.incrementAndGet()), "a third concurrent call");
            Expect.isTrue(e.getMessage().contains("inventory"),
                "the rejection should name the bulkhead");
            Expect.equal(0, ran.get(), "a rejected operation must not run");
        } finally {
            drain();
        }
    }

    @Check(id = "rejection-does-not-wait")
    void rejectionDoesNotWait() throws Exception {
        Bulkhead b = new Bulkhead("inventory", 1);
        occupy(b, 1);
        try {
            Expect.completesWithin(300, () -> {
                Expect.raises(BulkheadFullException.class,
                    () -> b.call(() -> "x"), "a call to a full bulkhead");
                return null;
            }, "a call to a full bulkhead (it must reject, not queue)");
        } finally {
            drain();
        }
    }

    @Check(id = "permit-returned-after-success")
    void permitReturnedAfterSuccess() throws Exception {
        Bulkhead b = new Bulkhead("inventory", 2);
        occupy(b, 2);
        drain();
        for (int i = 0; i < 5; i++) {
            Expect.equal("ok", b.call(() -> "ok"), "call " + (i + 1) + " after the holders finished");
        }
    }

    @Check(id = "permit-returned-after-failure")
    void permitReturnedAfterFailure() {
        Bulkhead b = new Bulkhead("payments", 1);
        for (int i = 0; i < 3; i++) {
            IllegalStateException e = Expect.raises(IllegalStateException.class,
                () -> b.call(() -> {
                    throw new IllegalStateException("boom");
                }), "a failing operation");
            Expect.equal("boom", e.getMessage(), "the original exception");
        }
        Expect.equal("ok", b.call(() -> "ok"), "a call after the failures");
    }

    @Check(id = "bulkheads-are-independent")
    void bulkheadsAreIndependent() throws Exception {
        Bulkhead inventory = new Bulkhead("inventory", 1);
        Bulkhead payments = new Bulkhead("payments", 1);
        occupy(inventory, 1);
        try {
            Expect.equal("paid", payments.call(() -> "paid"),
                "a call to payments while inventory is full");
        } finally {
            drain();
        }
    }

    @Check(id = "never-exceeds-the-limit")
    void neverExceedsTheLimit() {
        // Callers hammer a bulkhead of 2 with short calls: a check-then-act
        // admission soon lets a third caller slip in.
        Bulkhead b = new Bulkhead("inventory", 2);
        AtomicInteger inside = new AtomicInteger();
        AtomicInteger peak = new AtomicInteger();
        List<Integer> admitted = Stress.race(6, () -> {
            int in = 0;
            for (int i = 0; i < 20_000 && peak.get() <= 2; i++) {
                try {
                    b.call(() -> {
                        peak.accumulateAndGet(inside.incrementAndGet(), Math::max);
                        Thread.onSpinWait();
                        inside.decrementAndGet();
                        return "x";
                    });
                    in++;
                } catch (BulkheadFullException e) {
                    // rejected: try again
                }
            }
            return in;
        });
        Expect.isTrue(peak.get() <= 2, "a bulkhead of 2 let " + peak.get()
            + " racing calls in at once; take a permit in one atomic step");
        Expect.isTrue(admitted.stream().mapToInt(Integer::intValue).sum() > 0,
            "some of the racing calls should be admitted");
    }

    @Check(id = "limit-is-per-instance", kind = Kind.DESIGN)
    void limitIsPerInstance() {
        for (Field f : Types.named("Bulkhead").getDeclaredFields()) {
            int m = f.getModifiers();
            boolean constant = Modifier.isFinal(m)
                && (f.getType().isPrimitive() || f.getType() == String.class);
            Expect.isTrue(!Modifier.isStatic(m) || constant,
                "Bulkhead." + f.getName() + " is static, so every bulkhead "
                    + "shares it; each bulkhead needs its own permits");
        }
    }

    @Check(id = "admission-never-waits", kind = Kind.DESIGN)
    void admissionNeverWaits() {
        var bulkhead = Source.type("Bulkhead");
        List<Hit> waits = new ArrayList<>();
        for (String w : List.of("acquire", "acquireUninterruptibly", "wait",
                "sleep", "await", "join", "take")) {
            waits.addAll(bulkhead.calls(w));
        }
        for (String w : List.of("tryAcquire", "tryLock", "offer", "poll")) {
            bulkhead.calls(w).stream()
                .filter(h -> h.args().contains(",")).forEach(waits::add);
        }
        Expect.none(waits, "Bulkhead waits for a permit; a full bulkhead must "
            + "reject at once (tryAcquire() without a timeout)");
    }
}
