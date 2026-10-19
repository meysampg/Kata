import java.util.function.LongSupplier;

// Starts full. Refills perSecond tokens per second, up to capacity.
final class TokenBucket {
    private final double capacity;
    private final double perSecond;
    private final LongSupplier nanos;

    TokenBucket(int capacity, double perSecond, LongSupplier nanos) {
        this.capacity = capacity;
        this.perSecond = perSecond;
        this.nanos = nanos;
    }

    /** Returns 0 if admitted, else the milliseconds until a token exists. */
    long acquire() {
        throw new UnsupportedOperationException("TODO");
    }
}
