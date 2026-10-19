import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.atomic.AtomicLong;

record Job(int amount) { }

final class Pipeline {
    // Compared by identity, so no real amount can ever equal it.
    private static final Job STOP = new Job(0);
    private final BlockingQueue<Job> queue = new ArrayBlockingQueue<>(2);

    long process(List<Integer> amounts, int consumers)
            throws InterruptedException {
        AtomicLong total = new AtomicLong();
        List<Thread> threads = new ArrayList<>();
        for (int c = 0; c < consumers; c++) {
            Thread t = new Thread(() -> consume(total));
            t.start();
            threads.add(t);
        }
        for (int amount : amounts) {
            queue.put(new Job(amount));
        }
        for (int c = 0; c < consumers; c++) {
            queue.put(STOP);
        }
        for (Thread t : threads) {
            t.join();
        }
        return total.get();
    }

    private void consume(AtomicLong total) {
        try {
            for (Job job; (job = queue.take()) != STOP; ) {
                total.addAndGet(job.amount());
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
}
