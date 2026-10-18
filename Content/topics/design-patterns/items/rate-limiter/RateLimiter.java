import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.atomic.AtomicLong;
import java.util.function.LongSupplier;

// [[bucket
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

    /** Returns 0 if admitted, else milliseconds until a token exists. */
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
// ]]

// [[perClient
final class Limiter {
    private final Map<String, TokenBucket> buckets = new HashMap<>();
    private final LongSupplier nanos;

    Limiter(LongSupplier nanos) { this.nanos = nanos; }

    synchronized long acquire(String client) {
        return buckets
            .computeIfAbsent(client, c -> new TokenBucket(3, 2, nanos))
            .acquire();
    }
}
// ]]

class Main {
    public static void main(String[] args) {
        var clock = new AtomicLong();
        var limiter = new Limiter(clock::get);
        // [[demo
        String[] who = {"a", "a", "a", "a", "b", "a", "a", "a", "a", "a", "a"};
        long[] atMs = {0, 0, 0, 0, 0, 500, 500, 10_000, 10_000, 10_000, 10_000};
        for (int i = 0; i < who.length; i++) {
            clock.set(atMs[i] * 1_000_000);
            long wait = limiter.acquire(who[i]);
            System.out.println(atMs[i] + "ms " + who[i] + " "
                + (wait == 0 ? "200" : "429 retry-after=" + wait + "ms"));
        }
        // ]]
    }
}
