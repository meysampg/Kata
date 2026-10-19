import java.util.Objects;
import java.util.Optional;
import java.util.concurrent.TimeUnit;

final class Slot<T> {
    private T item;

    synchronized void put(T newItem) throws InterruptedException {
        Objects.requireNonNull(newItem, "item");
        while (item != null) {
            wait();
        }
        item = newItem;
        notifyAll();
    }

    synchronized T take() throws InterruptedException {
        while (item == null) {
            wait();
        }
        return removeItem();
    }

    synchronized Optional<T> take(long timeoutMs) throws InterruptedException {
        long left = TimeUnit.MILLISECONDS.toNanos(timeoutMs);
        long deadline = System.nanoTime() + left;
        while (item == null) {
            left = deadline - System.nanoTime();
            if (left <= 0) {
                return Optional.empty();
            }
            TimeUnit.NANOSECONDS.timedWait(this, left);
        }
        return Optional.of(removeItem());
    }

    private T removeItem() {
        T taken = item;
        item = null;
        notifyAll();
        return taken;
    }
}
