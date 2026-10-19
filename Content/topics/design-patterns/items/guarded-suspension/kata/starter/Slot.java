import java.util.Optional;

// A one-item hand-off between threads.
final class Slot<T> {
    // Blocks while the slot is full, then stores the item. Null is rejected.
    void put(T item) throws InterruptedException {
        throw new UnsupportedOperationException("TODO");
    }

    // Blocks while the slot is empty, then removes and returns the item.
    T take() throws InterruptedException {
        throw new UnsupportedOperationException("TODO");
    }

    // Like take(), but gives up after timeoutMs milliseconds with empty.
    Optional<T> take(long timeoutMs) throws InterruptedException {
        throw new UnsupportedOperationException("TODO");
    }
}
