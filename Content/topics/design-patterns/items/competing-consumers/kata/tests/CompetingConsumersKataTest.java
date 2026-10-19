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

    @Check(id = "worker-ends-on-interrupt", timeoutMs = 4000)
    void workerEndsOnInterrupt() throws Exception {
        BlockingQueue<Job> queue = new LinkedBlockingQueue<>();
        Thread t = new Thread(new Worker(queue, job -> { }));
        t.setDaemon(true);
        t.start();
        Stress.pause(20);
        t.interrupt();
        t.join(2000);
        Expect.isTrue(!t.isAlive(), "A worker blocked on an empty queue should stop when interrupted");
    }

    @Check(id = "each-job-once", timeoutMs = 4000)
    void eachJobOnce() throws Exception {
        Map<Integer, Integer> handled = new ConcurrentHashMap<>();
        WorkerPool pool = new WorkerPool(4, job -> handled.merge(job.id(), 1, Integer::sum));
        for (int i = 1; i <= 300; i++) pool.submit(new Job(i, i));
        pool.shutdown();
        Expect.equal(300, handled.size(), "distinct jobs handled");
        Expect.isTrue(handled.values().stream().allMatch(n -> n == 1),
            "Some job was handled more than once: " + handled);
    }

    @Check(id = "jobs-run-in-parallel", timeoutMs = 5000)
    void jobsRunInParallel() throws Exception {
        CountDownLatch bothInside = new CountDownLatch(2);
        AtomicInteger finished = new AtomicInteger();
        WorkerPool pool = new WorkerPool(2, job -> {
            bothInside.countDown();
            if (bothInside.await(3, TimeUnit.SECONDS)) finished.incrementAndGet();
        });
        pool.submit(new Job(1, 1));
        pool.submit(new Job(2, 1));
        pool.shutdown();
        Expect.equal(2, finished.get(),
            "Two jobs should be in progress at the same time with two workers");
    }

    @Check(id = "shutdown-drains-queue", timeoutMs = 4000)
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
