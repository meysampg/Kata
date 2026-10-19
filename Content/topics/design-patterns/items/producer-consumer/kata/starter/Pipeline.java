import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.atomic.AtomicLong;

record Job(int amount) { }

// One producer (the caller) feeds a bounded queue; consumer threads add
// the amounts up. process() should return once the work is done.
final class Pipeline {
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
        for (Thread t : threads) {
            t.join();
        }
        return total.get();
    }

    private void consume(AtomicLong total) {
        try {
            while (true) {
                total.addAndGet(queue.take().amount());
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
}
