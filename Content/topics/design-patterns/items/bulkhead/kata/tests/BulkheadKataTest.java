import java.lang.reflect.Field;
import java.lang.reflect.Modifier;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.function.Supplier;
import kata.*;

class BulkheadKataTest {
    final CountDownLatch release = new CountDownLatch(1);
    final List<Thread> holders = new ArrayList<>();

    /** Starts calls that stay inside the bulkhead until release is counted down. */
    void occupy(Bulkhead b, int n) throws InterruptedException {
        CountDownLatch entered = new CountDownLatch(n);
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
            holders.add(t);
            t.start();
        }
        Expect.isTrue(entered.await(1, TimeUnit.SECONDS),
            "calls within the limit should be admitted");
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

    @Check(id = "rejects-when-full", timeoutMs = 4000)
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

    @Check(id = "rejection-does-not-wait", timeoutMs = 4000)
    void rejectionDoesNotWait() throws Exception {
        Bulkhead b = new Bulkhead("inventory", 1);
        occupy(b, 1);
        try {
            Expect.completesWithin(1000, () -> {
                Expect.raises(BulkheadFullException.class,
                    () -> b.call(() -> "x"), "a call to a full bulkhead");
                return null;
            }, "a call to a full bulkhead (it must reject, not queue)");
        } finally {
            drain();
        }
    }

    @Check(id = "permit-returned-after-success", timeoutMs = 4000)
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

    @Check(id = "bulkheads-are-independent", timeoutMs = 4000)
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

    @Check(id = "never-exceeds-the-limit", timeoutMs = 5000)
    void neverExceedsTheLimit() {
        Bulkhead b = new Bulkhead("inventory", 3);
        AtomicInteger inside = new AtomicInteger();
        AtomicInteger peak = new AtomicInteger();
        List<Boolean> admitted = Stress.race(12, () -> {
            try {
                b.call(() -> {
                    peak.accumulateAndGet(inside.incrementAndGet(), Math::max);
                    Stress.pause(10);
                    inside.decrementAndGet();
                    return "x";
                });
                return true;
            } catch (BulkheadFullException e) {
                return false;
            }
        });
        Expect.isTrue(peak.get() <= 3,
            "at most 3 calls may be inside at once, saw " + peak.get());
        Expect.isTrue(admitted.stream().anyMatch(a -> a),
            "some of the racing calls should be admitted");
    }

    @Check(id = "limit-is-per-instance", kind = Kind.DESIGN)
    void limitIsPerInstance() {
        for (Field f : Types.named("Bulkhead").getDeclaredFields()) {
            int m = f.getModifiers();
            Expect.isTrue(!Modifier.isStatic(m) || Modifier.isFinal(m),
                "Bulkhead." + f.getName() + " is shared mutable static state; "
                    + "each bulkhead needs its own permits");
        }
    }

    @Check(id = "operation-runs-outside-a-monitor", kind = Kind.DESIGN)
    void operationRunsOutsideAMonitor() {
        var call = Source.type("Bulkhead").method("call");
        List<Hit> inside = call.calls("get").stream().filter(Hit::insideSynchronized).toList();
        Expect.none(inside, "Bulkhead runs the operation inside synchronized");
        Expect.none(call.calls("sleep"), "Bulkhead must not sleep");
    }
}
