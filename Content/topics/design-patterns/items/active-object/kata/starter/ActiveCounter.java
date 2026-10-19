import java.util.concurrent.CompletableFuture;

// Callers get a future at once; one scheduler thread runs the requests
// against the servant, one at a time, in the order they arrived.
final class ActiveCounter implements AutoCloseable {
    /** Starts the scheduler thread. */
    ActiveCounter(Counter servant) {
        throw new UnsupportedOperationException("TODO");
    }

    /** Resolves to the servant's new total. */
    CompletableFuture<Integer> add(int n) {
        throw new UnsupportedOperationException("TODO");
    }

    /** Resolves to the servant's current total. */
    CompletableFuture<Integer> total() {
        throw new UnsupportedOperationException("TODO");
    }

    /**
     * Finishes the requests already accepted, stops the scheduler and
     * returns once it has exited. Later requests are refused.
     */
    @Override
    public void close() {
        throw new UnsupportedOperationException("TODO");
    }
}
