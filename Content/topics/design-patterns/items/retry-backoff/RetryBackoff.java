import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.function.LongUnaryOperator;
import java.util.function.Supplier;

// [[errors
@SuppressWarnings("serial")
class TransientException extends RuntimeException {
    TransientException(String message) { super(message); }
}
@SuppressWarnings("serial")
class PermanentException extends RuntimeException {
    PermanentException(String message) { super(message); }
}
// ]]

interface Sleeper { void sleep(Duration d); }

// [[policy
record Retry(int maxAttempts, long baseMs, long capMs,
             LongUnaryOperator jitter, Sleeper sleeper) {

    long delayMs(int attempt) {
        long ceiling = Math.min(capMs, baseMs << Math.min(attempt - 1, 20));
        return jitter.applyAsLong(ceiling);
    }

    <T> T call(Supplier<T> op) {
        for (int attempt = 1; ; attempt++) {
            try {
                return op.get();
            } catch (TransientException e) {
                if (attempt == maxAttempts) throw e;
                sleeper.sleep(Duration.ofMillis(delayMs(attempt)));
            }
        }
    }
}
// ]]

class Main {
    static Supplier<String> failing(int times, RuntimeException error) {
        int[] calls = {0};
        return () -> {
            if (calls[0]++ < times) throw error;
            return "ok";
        };
    }

    static void run(String label, int attempts, Supplier<String> op) {
        List<Long> waits = new ArrayList<>();
        // [[wiring
        LongUnaryOperator half = ceiling -> ceiling / 2;  // test jitter
        Retry retry = new Retry(attempts, 100, 1000, half,
            d -> waits.add(d.toMillis()));
        // ]]
        String result;
        try {
            result = retry.call(op);
        } catch (RuntimeException e) {
            result = e.getClass().getSimpleName();
        }
        System.out.println(label + ": " + result + " waits=" + waits);
    }

    public static void main(String[] args) {
        var busy = new TransientException("503");
        run("flaky", 5, failing(3, busy));
        run("down", 3, failing(99, busy));
        run("bad", 5, failing(99, new PermanentException("400")));
    }
}
