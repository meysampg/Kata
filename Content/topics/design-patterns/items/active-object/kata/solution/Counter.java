import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

// The servant. It is not thread-safe on purpose: exactly one thread may
// ever call it. It records every thread that does.
class Counter {
    private final Set<Thread> callers = ConcurrentHashMap.newKeySet();
    private int total;

    int add(int n) {
        callers.add(Thread.currentThread());
        if (n < 0) {
            throw new IllegalArgumentException("negative: " + n);
        }
        return total += n;
    }

    int total() {
        callers.add(Thread.currentThread());
        return total;
    }

    Set<Thread> callers() {
        return Set.copyOf(callers);
    }
}
