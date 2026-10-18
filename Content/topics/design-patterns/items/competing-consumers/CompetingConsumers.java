import java.util.concurrent.BlockingQueue;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Executors;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.atomic.AtomicLong;

// [[message
record Job(int id, int cost) {
    static final Job STOP = new Job(-1, 0);
}
// ]]

// [[consumer
final class Worker implements Runnable {
    private final BlockingQueue<Job> queue;
    private final ConcurrentHashMap<Integer, Integer> handled;
    private final AtomicLong total;

    Worker(BlockingQueue<Job> queue,
           ConcurrentHashMap<Integer, Integer> handled, AtomicLong total) {
        this.queue = queue;
        this.handled = handled;
        this.total = total;
    }

    public void run() {
        try {
            while (true) {
                Job job = queue.take();
                if (job == Job.STOP) return;
                handled.merge(job.id(), 1, Integer::sum);
                total.addAndGet(job.cost());
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
}
// ]]

class Main {
    public static void main(String[] args) throws InterruptedException {
        // [[queue
        var queue = new LinkedBlockingQueue<Job>();
        var handled = new ConcurrentHashMap<Integer, Integer>();
        var total = new AtomicLong();
        int workers = 4;
        // ]]
        try (var pool = Executors.newVirtualThreadPerTaskExecutor()) {
            // [[start
            for (int w = 0; w < workers; w++) {
                pool.submit(new Worker(queue, handled, total));
            }
            // ]]
            // [[produce
            for (int i = 1; i <= 20; i++) queue.put(new Job(i, i));
            // ]]
            // [[stop
            for (int w = 0; w < workers; w++) queue.put(Job.STOP);
            // ]]
        } // close() waits for every worker to finish
        boolean once = handled.values().stream().allMatch(n -> n == 1);
        System.out.println("jobs=" + handled.size()
            + " exactlyOnce=" + once + " total=" + total.get());
    }
}
