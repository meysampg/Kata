import java.util.Iterator;

// Keeps the most recent log lines. When full, add() overwrites the oldest.
final class RingBuffer<T> implements Iterable<T> {
    private final Object[] slots;
    private int start;     // index of the oldest element
    private int size;
    private int modCount;  // bump it on every add

    RingBuffer(int capacity) {
        if (capacity < 1) {
            throw new IllegalArgumentException("capacity");
        }
        slots = new Object[capacity];
    }

    int size() { return size; }

    void add(T item) {
        throw new UnsupportedOperationException("TODO");
    }

    @Override
    public Iterator<T> iterator() {
        throw new UnsupportedOperationException("TODO");
    }
}
