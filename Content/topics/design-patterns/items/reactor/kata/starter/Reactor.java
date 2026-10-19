// A single-threaded event loop: wait for ready events, hand each one to
// the handler registered for its operation.
final class Reactor {
    Reactor(Demultiplexer demux) {
        throw new UnsupportedOperationException("TODO");
    }

    /** Registers the handler for an operation, replacing any earlier one. */
    Reactor on(Op op, Handler handler) {
        throw new UnsupportedOperationException("TODO");
    }

    /**
     * Calls select() again and again, dispatching every event of a batch in
     * order on this thread, until select() returns an empty list or stop()
     * was called (the current batch is finished first).
     */
    void run() {
        throw new UnsupportedOperationException("TODO");
    }

    /** Ends run() after the batch being dispatched. */
    void stop() {
        throw new UnsupportedOperationException("TODO");
    }
}
