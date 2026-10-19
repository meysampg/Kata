import java.util.function.LongSupplier;
import java.util.function.Supplier;

// Protects a shaky dependency: stop calling it while it is down.
final class CircuitBreaker {
    private final int threshold;
    private final long openMs;
    private final LongSupplier clock;
    private State state = State.CLOSED;
    private int failures;
    private long openedAt;

    CircuitBreaker(int threshold, long openMs, LongSupplier clock) {
        this.threshold = threshold;
        this.openMs = openMs;
        this.clock = clock;
    }

    synchronized State state() { return state; }

    <T> T call(Supplier<T> op, Supplier<T> fallback) {
        if (!permit()) {
            return fallback.get();
        }
        try {
            T result = op.get();
            record(true);
            return result;
        } catch (RuntimeException e) {
            record(false);
            return fallback.get();
        }
    }

    // The caller that flips OPEN to HALF_OPEN is the single probe.
    private synchronized boolean permit() {
        if (state == State.OPEN && clock.getAsLong() - openedAt >= openMs) {
            state = State.HALF_OPEN;
            return true;
        }
        return state == State.CLOSED;
    }

    private synchronized void record(boolean ok) {
        if (ok) {
            state = State.CLOSED;
            failures = 0;
        } else if (state == State.HALF_OPEN || ++failures >= threshold) {
            state = State.OPEN;
            openedAt = clock.getAsLong();
        }
    }
}
