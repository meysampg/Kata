import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;

// [[message
sealed interface Msg permits Job, Stop {}
record Job(int amount) implements Msg {}
record Stop() implements Msg {}
// ]]

class Main {
    public static void main(String[] args) {
        // [[queue
        BlockingQueue<Msg> queue = new ArrayBlockingQueue<>(2);
        // ]]
        var total = new AtomicLong();
        var jobs = new AtomicInteger();
        int consumers = 3;
        try (var exec = Executors.newVirtualThreadPerTaskExecutor()) {
            // [[consume
            for (int c = 0; c < consumers; c++) {
                exec.submit(() -> {
                    while (queue.take() instanceof Job job) {
                        total.addAndGet(job.amount());
                        jobs.incrementAndGet();
                    }
                    return null;
                });
            }
            // ]]
            // [[produce
            exec.submit(() -> {
                for (int i = 1; i <= 10; i++) queue.put(new Job(i));
                for (int c = 0; c < consumers; c++) queue.put(new Stop());
                return null;
            });
            // ]]
        }
        // [[result
        System.out.println("jobs=" + jobs + " total=" + total);
        System.out.println("queue drained=" + queue.isEmpty());
        // ]]
    }
}
