import java.util.function.LongSupplier;

// One bucket per client, all with the same capacity and rate.
final class Limiter {
    private final int capacity;
    private final double perSecond;
    private final LongSupplier nanos;

    Limiter(int capacity, double perSecond, LongSupplier nanos) {
        this.capacity = capacity;
        this.perSecond = perSecond;
        this.nanos = nanos;
    }

    /** 0 if the client may proceed, else the retry-after in ms. */
    long acquire(String client) {
        throw new UnsupportedOperationException("TODO");
    }
}
