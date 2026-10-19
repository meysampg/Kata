import java.time.Duration;
import java.util.function.LongUnaryOperator;
import java.util.function.Supplier;

// Retries transient failures with capped exponential backoff.
final class Retry {
    private final int maxAttempts;
    private final long baseMs;
    private final long capMs;
    private final LongUnaryOperator jitter;
    private final Sleeper sleeper;

    Retry(int maxAttempts, long baseMs, long capMs,
          LongUnaryOperator jitter, Sleeper sleeper) {
        this.maxAttempts = maxAttempts;
        this.baseMs = baseMs;
        this.capMs = capMs;
        this.jitter = jitter;
        this.sleeper = sleeper;
    }

    /** The ceiling for a 1-based attempt, before jitter is applied. */
    long ceilingMs(int attempt) {
        throw new UnsupportedOperationException("TODO");
    }

    <T> T call(Supplier<T> op) {
        throw new UnsupportedOperationException("TODO");
    }
}
