import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.LinkedBlockingQueue;

final class WorkerPool {
    private final BlockingQueue<Job> queue = new LinkedBlockingQueue<>();
    private final List<Thread> threads = new ArrayList<>();

    WorkerPool(int workers, JobHandler handler) {
        for (int i = 0; i < workers; i++) {
            Thread t = Thread.ofVirtual().unstarted(new Worker(queue, handler));
            threads.add(t);
            t.start();
        }
    }

    void submit(Job job) {
        queue.add(job);
    }

    void shutdown() throws InterruptedException {
        for (int i = 0; i < threads.size(); i++) {
            queue.add(Job.STOP);
        }
        for (Thread t : threads) {
            t.join();
        }
    }
}
