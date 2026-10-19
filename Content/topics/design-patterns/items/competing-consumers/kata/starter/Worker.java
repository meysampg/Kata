import java.util.concurrent.BlockingQueue;

// One consumer: takes jobs from a queue it shares with its siblings.
final class Worker implements Runnable {
    Worker(BlockingQueue<Job> queue, JobHandler handler) {
        throw new UnsupportedOperationException("TODO");
    }

    @Override
    public void run() {
        throw new UnsupportedOperationException("TODO");
    }
}
