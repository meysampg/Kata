// N workers competing for one queue.
final class WorkerPool {
    WorkerPool(int workers, JobHandler handler) {
        throw new UnsupportedOperationException("TODO");
    }

    void submit(Job job) {
        throw new UnsupportedOperationException("TODO");
    }

    /** Lets queued jobs finish, stops every worker, returns when all ended. */
    void shutdown() throws InterruptedException {
        throw new UnsupportedOperationException("TODO");
    }
}
