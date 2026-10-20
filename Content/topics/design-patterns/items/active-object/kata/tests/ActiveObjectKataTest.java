import java.lang.reflect.Field;
import java.lang.reflect.Modifier;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import java.util.concurrent.locks.Lock;
import kata.*;

class ActiveObjectKataTest {
    static int value(CompletableFuture<Integer> future, String what)
            throws Throwable {
        try {
            return future.get(2, TimeUnit.SECONDS);
        } catch (TimeoutException e) {
            throw new CheckFailure(what + " did not complete within 2000 ms");
        } catch (ExecutionException e) {
            throw e.getCause();
        }
    }

    static class GatedCounter extends Counter {
        final CountDownLatch entered = new CountDownLatch(1);
        final CountDownLatch gate = new CountDownLatch(1);

        @Override
        int add(int n) {
            entered.countDown();
            try {
                gate.await(5, TimeUnit.SECONDS);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
            return super.add(n);
        }
    }

    @Check(id = "add-returns-the-new-total", timeoutMs = 4000)
    void addReturnsTheNewTotal() throws Throwable {
        try (var active = new ActiveCounter(new Counter())) {
            Expect.equal(5, value(active.add(5), "add(5)"), "add(5)");
            Expect.equal(12, value(active.add(7), "add(7)"), "add(7)");
            Expect.equal(12, value(active.total(), "total()"), "total()");
        }
    }

    @Check(id = "requests-run-in-submission-order", timeoutMs = 4000)
    void requestsRunInSubmissionOrder() throws Throwable {
        try (var active = new ActiveCounter(new Counter())) {
            List<CompletableFuture<Integer>> all = new ArrayList<>();
            for (int i = 0; i < 100; i++) {
                all.add(active.add(1));
            }
            for (int i = 0; i < 100; i++) {
                Expect.equal(i + 1, value(all.get(i), "request " + (i + 1)),
                    "result of request " + (i + 1));
            }
        }
    }

    @Check(id = "every-call-runs-on-one-scheduler-thread", timeoutMs = 5000)
    void everyCallRunsOnOneSchedulerThread() throws Throwable {
        Counter servant = new Counter();
        try (var active = new ActiveCounter(servant)) {
            List<List<CompletableFuture<Integer>>> batches = Stress.race(8,
                () -> {
                    List<CompletableFuture<Integer>> mine = new ArrayList<>();
                    for (int i = 0; i < 25; i++) {
                        mine.add(active.add(1));
                    }
                    return mine;
                });
            for (var batch : batches) {
                for (var f : batch) {
                    value(f, "a concurrent add");
                }
            }
            Expect.equal(200, value(active.total(), "total()"),
                "total after 8 threads added 25 times each");
            var callers = servant.callers();
            Expect.equal(1, callers.size(),
                "threads that touched the servant");
            Thread only = callers.iterator().next();
            Expect.isTrue(only != Thread.currentThread()
                    && !only.getName().startsWith("kata-race"),
                "the servant ran on a caller's thread; it must run on the "
                + "scheduler thread");
        }
    }

    @Check(id = "caller-does-not-wait", timeoutMs = 5000)
    void callerDoesNotWait() throws Throwable {
        GatedCounter servant = new GatedCounter();
        var active = new ActiveCounter(servant);
        try {
            var first = Expect.completesWithin(500, () -> active.add(1),
                "add(1) whose request keeps the servant busy");
            Expect.isTrue(servant.entered.await(2, TimeUnit.SECONDS),
                "The scheduler never started the first request");
            var second = Expect.completesWithin(500, () -> active.add(2),
                "add(2) while the scheduler is busy");
            var total = Expect.completesWithin(500, active::total,
                "total() while the scheduler is busy");
            Expect.isTrue(!first.isDone() && !second.isDone(),
                "Requests finished although the servant is still busy");
            servant.gate.countDown();
            Expect.equal(1, value(first, "add(1)"), "add(1)");
            Expect.equal(3, value(second, "add(2)"), "add(2)");
            Expect.equal(3, value(total, "total()"), "total()");
        } finally {
            // Open the gate before close(), so close() never waits on it.
            servant.gate.countDown();
            active.close();
        }
    }

    @Check(id = "failure-reaches-the-future", timeoutMs = 4000)
    void failureReachesTheFuture() throws Throwable {
        try (var active = new ActiveCounter(new Counter())) {
            Expect.equal(4, value(active.add(4), "add(4)"), "add(4)");
            Expect.raises(IllegalArgumentException.class,
                () -> value(active.add(-1), "add(-1)"), "add(-1)");
            Expect.equal(9, value(active.add(5), "add(5)"),
                "add(5) after a failed request");
        }
    }

    @Check(id = "close-finishes-accepted-work", timeoutMs = 5000)
    void closeFinishesAcceptedWork() throws Throwable {
        Counter servant = new Counter();
        var active = new ActiveCounter(servant);
        List<CompletableFuture<Integer>> all = new ArrayList<>();
        for (int i = 0; i < 50; i++) {
            all.add(active.add(1));
        }
        Expect.completesWithin(2000, () -> {
            active.close();
            return null;
        }, "close()");
        for (int i = 0; i < 50; i++) {
            Expect.isTrue(all.get(i).isDone(),
                "Request " + (i + 1) + " was dropped by close()");
        }
        Expect.equal(50, value(all.get(49), "last add"), "last result");
        Thread scheduler = servant.callers().iterator().next();
        scheduler.join(1000);
        Expect.isTrue(!scheduler.isAlive(),
            "The scheduler thread is still alive after close()");
    }

    @Check(id = "refuses-requests-after-close", timeoutMs = 4000)
    void refusesRequestsAfterClose() throws Throwable {
        var active = new ActiveCounter(new Counter());
        active.close();
        boolean refused = Expect.completesWithin(1500, () -> {
            try {
                active.add(1).get(1, TimeUnit.SECONDS);
                return false;
            } catch (ExecutionException | RuntimeException e) {
                return true;
            }
        }, "add(1) after close()");
        Expect.isTrue(refused, "add(1) after close() should be refused, "
            + "by an exception or a failed future");
    }

    @Check(id = "servant-is-private-final", kind = Kind.DESIGN)
    void servantIsPrivateFinal() {
        Field f = Types.onlyFieldOfType(ActiveCounter.class, Counter.class);
        int m = f.getModifiers();
        Expect.isTrue(Modifier.isPrivate(m) && Modifier.isFinal(m),
            "ActiveCounter." + f.getName() + " should be private final");
    }

    @Check(id = "no-locking-around-the-servant", kind = Kind.DESIGN)
    void noLockingAroundTheServant() {
        for (Field f : ActiveCounter.class.getDeclaredFields()) {
            Expect.isTrue(!Lock.class.isAssignableFrom(f.getType())
                    && !java.util.concurrent.Semaphore.class
                        .isAssignableFrom(f.getType()),
                "ActiveCounter." + f.getName() + " is a lock; the single "
                + "scheduler thread should make locks unnecessary");
        }
        var type = Source.type("ActiveCounter");
        Expect.none(type.mentions("ReentrantLock"),
            "ActiveCounter takes a lock around the servant");
    }
}
