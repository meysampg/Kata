import java.util.function.LongSupplier;
import java.util.function.Supplier;

// Protects a shaky dependency: stop calling it while it is down.
final class CircuitBreaker {
    private final int threshold;
    private final long openMs;
    private final LongSupplier clock;

    CircuitBreaker(int threshold, long openMs, LongSupplier clock) {
        this.threshold = threshold;
        this.openMs = openMs;
        this.clock = clock;
    }

    State state() {
        throw new UnsupportedOperationException("TODO");
    }

    <T> T call(Supplier<T> op, Supplier<T> fallback) {
        throw new UnsupportedOperationException("TODO");
    }
}
