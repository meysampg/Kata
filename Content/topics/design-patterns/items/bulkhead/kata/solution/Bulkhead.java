import java.util.concurrent.Semaphore;
import java.util.function.Supplier;

// One compartment per dependency: at most maxConcurrent calls inside.
final class Bulkhead {
    private final String name;
    private final Semaphore permits;

    Bulkhead(String name, int maxConcurrent) {
        this.name = name;
        this.permits = new Semaphore(maxConcurrent);
    }

    <T> T call(Supplier<T> op) {
        if (!permits.tryAcquire()) {
            throw new BulkheadFullException(name);
        }
        try {
            return op.get();
        } finally {
            permits.release();
        }
    }
}
