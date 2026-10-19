import java.util.concurrent.Executor;

// A small fixed pool: a bounded queue of tasks and worker threads.
// Build the bodies; the signatures are what the tests call.
final class MiniPool implements Executor {
    /** Starts {@code threads} workers that read a queue of {@code capacity}. */
    MiniPool(int threads, int capacity) {
        throw new UnsupportedOperationException("TODO");
    }

    /**
     * Queues the task, waiting while the queue is full. Once shutdown has
     * begun it throws RejectedExecutionException.
     */
    @Override
    public void execute(Runnable task) {
        throw new UnsupportedOperationException("TODO");
    }

    /**
     * Rejects new tasks, lets every queued task finish, and returns once
     * all workers have exited.
     */
    void shutdown() throws InterruptedException {
        throw new UnsupportedOperationException("TODO");
    }
}
