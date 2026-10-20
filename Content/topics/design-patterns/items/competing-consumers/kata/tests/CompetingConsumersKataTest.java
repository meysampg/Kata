import java.lang.reflect.Field;
import java.lang.reflect.Modifier;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;
import kata.*;

class CompetingConsumersKataTest {
    @Check(id = "worker-drains-until-stop")
    void workerDrainsUntilStop() {
        BlockingQueue<Job> queue = new LinkedBlockingQueue<>();
        List<Integer> seen = new java.util.ArrayList<>();
        queue.add(new Job(1, 1));
        queue.add(new Job(2, 1));
        queue.add(Job.STOP);
        queue.add(new Job(3, 1));
        new Worker(queue, job -> seen.add(job.id())).run();
        Expect.equal(List.of(1, 2), seen, "jobs handled before the poison pill");
        Expect.equal(1, queue.size(), "jobs left behind the poison pill");
    }

    @Check(id = "worker-survives-failing-job")
    void workerSurvivesFailure() {
        BlockingQueue<Job> queue = new LinkedBlockingQueue<>();
        List<Integer> seen = new java.util.ArrayList<>();
        queue.add(new Job(1, 1));
        queue.add(new Job(2, 1));
        queue.add(new Job(3, 1));
        queue.add(Job.STOP);
        new Worker(queue, job -> {
            if (job.id() == 2) throw new IllegalStateException("poison");
            seen.add(job.id());
        }).run();
        Expect.equal(List.of(1, 3), seen, "jobs handled around a failing one");
    }

    @Check(id = "worker-ends-on-interrupt")
    void workerEndsOnInterrupt() throws Exception {
        BlockingQueue<Job> queue = new LinkedBlockingQueue<>();
        AtomicBoolean flagKept = new AtomicBoolean();
        Thread t = new Thread(() -> {
            new Worker(queue, job -> { }).run();
            flagKept.set(Thread.currentThread().isInterrupted());
        });
        t.setDaemon(true);
        t.start();
        long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(1);
        while (t.getState() != Thread.State.WAITING
                && t.getState() != Thread.State.TIMED_WAITING
                && t.isAlive() && System.nanoTime() < deadline) {
            Thread.onSpinWait();   // until the worker blocks on the empty queue
        }
        Expect.isTrue(t.isAlive(), "A worker on an empty queue should wait for work");
        t.interrupt();
        t.join(1000);
        Expect.isTrue(!t.isAlive(), "A worker blocked on an empty queue should stop when interrupted");
        Expect.isTrue(flagKept.get(), "Worker.run swallowed the interrupt; "
            + "restore it with Thread.currentThread().interrupt()");
    }

    @Check(id = "each-job-once")
    void eachJobOnce() throws Exception {
        Map<Integer, Integer> handled = new ConcurrentHashMap<>();
        WorkerPool pool = new WorkerPool(4, job -> handled.merge(job.id(), 1, Integer::sum));
        for (int i = 1; i <= 300; i++) pool.submit(new Job(i, i));
        pool.shutdown();
        Expect.equal(300, handled.size(), "distinct jobs handled");
        Expect.isTrue(handled.values().stream().allMatch(n -> n == 1),
            "Some job was handled more than once: " + handled);
    }

    @Check(id = "jobs-run-in-parallel")
    void jobsRunInParallel() throws Exception {
        CountDownLatch bothInside = new CountDownLatch(2);
        AtomicInteger finished = new AtomicInteger();
        WorkerPool pool = new WorkerPool(2, job -> {
            bothInside.countDown();
            if (bothInside.await(1, TimeUnit.SECONDS)) finished.incrementAndGet();
        });
        pool.submit(new Job(1, 1));
        pool.submit(new Job(2, 1));
        pool.shutdown();
        Expect.equal(2, finished.get(),
            "Two jobs should be in progress at the same time with two workers");
    }

    @Check(id = "idle-worker-takes-next-job")
    void idleWorkerTakesNextJob() throws Exception {
        CountDownLatch slowStarted = new CountDownLatch(1);
        CountDownLatch release = new CountDownLatch(1);
        CountDownLatch othersDone = new CountDownLatch(3);
        WorkerPool pool = new WorkerPool(2, job -> {
            if (job.id() == 1) {
                slowStarted.countDown();
                release.await(2, TimeUnit.SECONDS);
            } else {
                othersDone.countDown();
            }
        });
        boolean freed;
        try {
            pool.submit(new Job(1, 100));
            Expect.isTrue(slowStarted.await(1, TimeUnit.SECONDS), "job 1 never started");
            for (int i = 2; i <= 4; i++) pool.submit(new Job(i, 1));
            freed = othersDone.await(1, TimeUnit.SECONDS);
        } finally {
            release.countDown();
        }
        pool.shutdown();
        Expect.isTrue(freed, "While job 1 runs, the idle worker should take jobs 2 "
            + "to 4; a job must not wait behind a busy worker (no per-worker queues)");
    }

    @Check(id = "shutdown-drains-queue")
    void shutdownDrains() throws Exception {
        AtomicInteger done = new AtomicInteger();
        WorkerPool pool = new WorkerPool(3, job -> {
            Stress.pause(1);
            done.incrementAndGet();
        });
        for (int i = 0; i < 60; i++) pool.submit(new Job(i, 1));
        pool.shutdown();
        Expect.equal(60, done.get(), "jobs finished when shutdown() returned");
    }

    @Check(id = "pool-shares-one-queue", kind = Kind.DESIGN)
    void poolSharesOneQueue() {
        Field f = Types.onlyFieldOfType(Types.named("WorkerPool"), BlockingQueue.class);
        Expect.isTrue(Modifier.isPrivate(f.getModifiers()) && Modifier.isFinal(f.getModifiers()),
            "WorkerPool." + f.getName() + " should be private final");
        Expect.isTrue(Types.fieldsOfType(Types.named("Worker"), BlockingQueue.class).size() == 1,
            "Each Worker should hold the shared queue, not a copy per worker");
    }

    @Check(id = "no-polling-or-locks", kind = Kind.DESIGN)
    void noPollingOrLocks() {
        for (String type : List.of("Worker", "WorkerPool")) {
            var shape = Source.type(type);
            Expect.none(shape.calls("sleep"), type + " sleeps to wait for work; block on the queue instead");
            Expect.none(shape.calls("isEmpty"), type + " polls isEmpty(); block on the queue instead");
        }
        Expect.none(Source.type("Worker").calls("wait"), "Worker uses wait/notify; the queue already blocks");
    }

    @Check(id = "worker-keeps-no-job-state", kind = Kind.DESIGN)
    void workerKeepsNoJobState() {
        for (Field f : Types.named("Worker").getDeclaredFields()) {
            Expect.isTrue(Modifier.isFinal(f.getModifiers()) && !Modifier.isStatic(f.getModifiers()),
                "Worker." + f.getName() + " should be a final instance field; "
                + "competing consumers share nothing mutable except the queue");
        }
    }
}
