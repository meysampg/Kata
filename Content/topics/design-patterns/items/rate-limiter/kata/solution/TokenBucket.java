import java.util.function.LongSupplier;

// Starts full. Refills perSecond tokens per second, up to capacity.
final class TokenBucket {
    private final double capacity;
    private final double perSecond;
    private final LongSupplier nanos;
    private double tokens;
    private long last;

    TokenBucket(int capacity, double perSecond, LongSupplier nanos) {
        this.capacity = capacity;
        this.perSecond = perSecond;
        this.nanos = nanos;
        this.tokens = capacity;
        this.last = nanos.getAsLong();
    }

    /** Returns 0 if admitted, else the milliseconds until a token exists. */
    synchronized long acquire() {
        long now = nanos.getAsLong();
        tokens = Math.min(capacity, tokens + (now - last) * perSecond / 1e9);
        last = now;
        if (tokens >= 1) {
            tokens -= 1;
            return 0;
        }
        return (long) Math.ceil((1 - tokens) / perSecond * 1000);
    }
}
