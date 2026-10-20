import java.lang.reflect.Field;
import java.util.List;
import java.util.Set;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.RejectedExecutionException;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;
import kata.*;

class ThreadPoolKataTest {
    /** Waits at the gate, giving up after five seconds. */
    static void waitAt(CountDownLatch gate) {
        try {
            gate.await(5, TimeUnit.SECONDS);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }

    static void await(CountDownLatch latch, String what) throws Exception {
        if (!latch.await(2, TimeUnit.SECONDS)) {
            throw new CheckFailure(what);
        }
    }

    static Thread background(Expect.ThrowingRunnable action,
            AtomicReference<Throwable> error) {
        Thread t = new Thread(null, () -> {
            try {
                action.run();
            } catch (Throwable e) {
                error.set(e);
            }
        }, "kata-caller", 0);
        t.setDaemon(true);
        t.start();
        return t;
    }

    /** Waits until the thread is parked (true) or has finished (false). */
    static boolean parks(Thread t) {
        long end = System.nanoTime() + 2_000_000_000L;
        while (System.nanoTime() < end) {
            Thread.State s = t.getState();
            if (s == Thread.State.TERMINATED) {
                return false;
            }
            if (s == Thread.State.WAITING || s == Thread.State.TIMED_WAITING) {
                return true;
            }
            Thread.yield();
        }
        return t.isAlive();
    }

    static void shutdownWithin(MiniPool pool, long ms) {
        Expect.completesWithin(ms, () -> {
            pool.shutdown();
            return null;
        }, "shutdown()");
    }

    @Check(id = "runs-every-task", timeoutMs = 5000)
    void runsEveryTask() throws Exception {
        MiniPool pool = new MiniPool(4, 8);
        AtomicInteger done = new AtomicInteger();
        for (int i = 0; i < 200; i++) {
            pool.execute(done::incrementAndGet);
        }
        shutdownWithin(pool, 3000);
        Expect.equal(200, done.get(), "tasks run after shutdown() returned");
    }

    @Check(id = "never-more-workers-than-threads", timeoutMs = 5000)
    void neverMoreWorkersThanThreads() throws Exception {
        MiniPool pool = new MiniPool(3, 10);
        CountDownLatch gate = new CountDownLatch(1);
        CountDownLatch started = new CountDownLatch(3);
        AtomicInteger running = new AtomicInteger();
        AtomicInteger most = new AtomicInteger();
        for (int i = 0; i < 6; i++) {
            pool.execute(() -> {
                most.accumulateAndGet(running.incrementAndGet(), Math::max);
                started.countDown();
                waitAt(gate);
                running.decrementAndGet();
            });
        }
        await(started, "Three tasks never ran at the same time");
        Stress.pause(30);
        gate.countDown();
        shutdownWithin(pool, 3000);
        Expect.equal(3, most.get(), "tasks running at the same time");
    }

    @Check(id = "threads-are-reused", timeoutMs = 5000)
    void threadsAreReused() throws Exception {
        MiniPool pool = new MiniPool(2, 4);
        Set<Thread> used = ConcurrentHashMap.newKeySet();
        for (int i = 0; i < 50; i++) {
            pool.execute(() -> used.add(Thread.currentThread()));
        }
        shutdownWithin(pool, 3000);
        Expect.isTrue(used.size() >= 1 && used.size() <= 2,
            "50 tasks ran on " + used.size() + " threads; a pool of 2 "
            + "should reuse its workers");
        Expect.isTrue(!used.contains(Thread.currentThread()),
            "tasks should not run on the caller's thread");
    }

    @Check(id = "execute-waits-when-queue-is-full", timeoutMs = 5000)
    void executeWaitsWhenQueueIsFull() throws Exception {
        MiniPool pool = new MiniPool(1, 1);
        CountDownLatch gate = new CountDownLatch(1);
        CountDownLatch started = new CountDownLatch(1);
        AtomicInteger done = new AtomicInteger();
        pool.execute(() -> {
            started.countDown();
            waitAt(gate);
            done.incrementAndGet();
        });
        await(started, "The first task never started");
        pool.execute(done::incrementAndGet);
        AtomicReference<Throwable> error = new AtomicReference<>();
        Thread third = background(() -> pool.execute(done::incrementAndGet),
            error);
        Expect.isTrue(parks(third), "execute() should wait while the "
            + "queue is full, but it returned");
        gate.countDown();
        third.join(2000);
        Expect.isTrue(!third.isAlive(), "execute() never returned after "
            + "room appeared in the queue");
        Expect.isTrue(error.get() == null, "execute() raised " + error.get());
        shutdownWithin(pool, 3000);
        Expect.equal(3, done.get(), "tasks run");
    }

    @Check(id = "shutdown-finishes-queued-tasks", timeoutMs = 5000)
    void shutdownFinishesQueuedTasks() throws Exception {
        MiniPool pool = new MiniPool(1, 10);
        CountDownLatch gate = new CountDownLatch(1);
        CountDownLatch started = new CountDownLatch(1);
        AtomicInteger done = new AtomicInteger();
        pool.execute(() -> {
            started.countDown();
            waitAt(gate);
            done.incrementAndGet();
        });
        await(started, "The first task never started");
        for (int i = 0; i < 5; i++) {
            pool.execute(done::incrementAndGet);
        }
        AtomicReference<Throwable> error = new AtomicReference<>();
        Thread closer = background(pool::shutdown, error);
        Expect.isTrue(parks(closer), "shutdown() returned while tasks "
            + "were still queued");
        gate.countDown();
        closer.join(3000);
        Expect.isTrue(!closer.isAlive(), "shutdown() never returned");
        Expect.isTrue(error.get() == null, "shutdown() raised " + error.get());
        Expect.equal(6, done.get(), "tasks run before shutdown() returned");
    }

    @Check(id = "rejects-after-shutdown", timeoutMs = 5000)
    void rejectsAfterShutdown() throws Exception {
        MiniPool pool = new MiniPool(2, 2);
        shutdownWithin(pool, 3000);
        Expect.raises(RejectedExecutionException.class,
            () -> pool.execute(() -> { }), "execute() after shutdown()");
    }

    @Check(id = "failing-task-keeps-worker-alive", timeoutMs = 5000)
    void failingTaskKeepsWorkerAlive() throws Exception {
        MiniPool pool = new MiniPool(1, 4);
        AtomicInteger done = new AtomicInteger();
        pool.execute(() -> {
            throw new IllegalStateException("boom");
        });
        pool.execute(done::incrementAndGet);
        pool.execute(done::incrementAndGet);
        shutdownWithin(pool, 3000);
        Expect.equal(2, done.get(),
            "tasks run after an earlier task threw");
    }

    @Check(id = "workers-exit-on-shutdown", timeoutMs = 5000)
    void workersExitOnShutdown() throws Exception {
        MiniPool pool = new MiniPool(3, 4);
        Set<Thread> used = ConcurrentHashMap.newKeySet();
        CountDownLatch all = new CountDownLatch(3);
        CountDownLatch gate = new CountDownLatch(1);
        for (int i = 0; i < 3; i++) {
            pool.execute(() -> {
                used.add(Thread.currentThread());
                all.countDown();
                waitAt(gate);
            });
        }
        await(all, "Three workers never ran");
        gate.countDown();
        shutdownWithin(pool, 3000);
        for (Thread worker : used) {
            worker.join(1000);
            Expect.isTrue(!worker.isAlive(), "Worker " + worker.getName()
                + " is still alive after shutdown()");
        }
    }

    @Check(id = "queue-is-bounded", kind = Kind.DESIGN)
    void queueIsBounded() throws Exception {
        MiniPool pool = new MiniPool(1, 5);
        Field found = null;
        for (Field f : MiniPool.class.getDeclaredFields()) {
            if (BlockingQueue.class.isAssignableFrom(f.getType())) {
                found = f;
            }
        }
        Expect.isTrue(found != null,
            "MiniPool should keep its tasks in a BlockingQueue field");
        found.setAccessible(true);
        BlockingQueue<?> queue = (BlockingQueue<?>) found.get(pool);
        Expect.equal(5, queue.remainingCapacity() + queue.size(),
            "capacity of the task queue");
        pool.shutdown();
    }

    @Check(id = "builds-its-own-workers", kind = Kind.DESIGN)
    void buildsItsOwnWorkers() {
        var pool = Source.type("MiniPool");
        for (String borrowed : List.of("Executors", "ThreadPoolExecutor",
                "ForkJoinPool", "CompletableFuture")) {
            Expect.none(pool.mentions(borrowed), "MiniPool borrows "
                + borrowed + " instead of building the pool itself");
        }
        var execute = pool.method("execute");
        Expect.none(execute.news("Thread"),
            "execute() creates a thread per task");
        Expect.none(execute.calls("start"),
            "execute() starts a thread per task");
    }
}
