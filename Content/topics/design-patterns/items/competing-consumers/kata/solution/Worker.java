import java.util.Objects;
import java.util.concurrent.BlockingQueue;

final class Worker implements Runnable {
    private final BlockingQueue<Job> queue;
    private final JobHandler handler;

    Worker(BlockingQueue<Job> queue, JobHandler handler) {
        this.queue = Objects.requireNonNull(queue, "queue");
        this.handler = Objects.requireNonNull(handler, "handler");
    }

    @Override
    public void run() {
        try {
            while (true) {
                Job job = queue.take();
                if (job == Job.STOP) {
                    return;
                }
                try {
                    handler.handle(job);
                } catch (Exception e) {
                    // one bad job must not kill the consumer
                }
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
}
