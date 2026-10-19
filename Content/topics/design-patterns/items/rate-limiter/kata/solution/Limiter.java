import java.util.HashMap;
import java.util.Map;
import java.util.function.LongSupplier;

// One bucket per client, all with the same capacity and rate.
final class Limiter {
    private final int capacity;
    private final double perSecond;
    private final LongSupplier nanos;
    private final Map<String, TokenBucket> buckets = new HashMap<>();

    Limiter(int capacity, double perSecond, LongSupplier nanos) {
        this.capacity = capacity;
        this.perSecond = perSecond;
        this.nanos = nanos;
    }

    /** 0 if the client may proceed, else the retry-after in ms. */
    synchronized long acquire(String client) {
        return buckets
            .computeIfAbsent(client,
                c -> new TokenBucket(capacity, perSecond, nanos))
            .acquire();
    }
}
