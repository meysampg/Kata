import java.util.concurrent.atomic.AtomicLong;
import java.util.function.LongSupplier;
import java.util.function.Supplier;

// [[state
enum State { CLOSED, OPEN, HALF_OPEN }
// ]]

final class CircuitBreaker {
    private final int threshold;
    private final long openMs;
    private final LongSupplier clock;
    private State state = State.CLOSED;
    private int failures;
    private long openedAt;

    CircuitBreaker(int threshold, long openMs, LongSupplier clock) {
        this.threshold = threshold; this.openMs = openMs; this.clock = clock;
    }
    synchronized State state() { return state; }

    // [[call
    <T> T call(Supplier<T> op, Supplier<T> fallback) {
        if (!permit()) return fallback.get();
        try {
            T result = op.get();
            record(true);
            return result;
        } catch (RuntimeException e) {
            record(false);
            return fallback.get();
        }
    }
    // ]]

    // [[permit
    private synchronized boolean permit() {
        if (state == State.OPEN && clock.getAsLong() - openedAt >= openMs) {
            state = State.HALF_OPEN;  // the caller that flips it is the probe
            return true;
        }
        return state == State.CLOSED;
    }
    // ]]

    // [[record
    private synchronized void record(boolean ok) {
        if (ok) {
            state = State.CLOSED;
            failures = 0;
        } else if (state == State.HALF_OPEN || ++failures >= threshold) {
            state = State.OPEN;
            openedAt = clock.getAsLong();
        }
    }
    // ]]
}

class Main {
    public static void main(String[] args) {
        var now = new AtomicLong();
        var breaker = new CircuitBreaker(3, 1000, now::get);
        int[] calls = {0};
        Supplier<String> op = () -> {
            calls[0]++;
            if (now.get() < 2000) throw new IllegalStateException("down");
            return "live";
        };
        for (long t : new long[] {0, 0, 0, 100, 1000, 1500, 2000, 2100}) {
            now.set(t);
            var r = breaker.call(op, () -> "cached");
            System.out.println(t + " " + r + " " + breaker.state()
                + " " + calls[0]);
        }
    }
}
