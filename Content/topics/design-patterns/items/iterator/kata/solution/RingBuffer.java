import java.util.ConcurrentModificationException;
import java.util.Iterator;
import java.util.NoSuchElementException;

final class RingBuffer<T> implements Iterable<T> {
    private final Object[] slots;
    private int start;
    private int size;
    private int modCount;

    RingBuffer(int capacity) {
        if (capacity < 1) {
            throw new IllegalArgumentException("capacity");
        }
        slots = new Object[capacity];
    }

    int size() { return size; }

    void add(T item) {
        if (size < slots.length) {
            slots[(start + size) % slots.length] = item;
            size++;
        } else {
            slots[start] = item;
            start = (start + 1) % slots.length;
        }
        modCount++;
    }

    @Override
    public Iterator<T> iterator() {
        return new Iterator<>() {
            private final int expected = modCount;
            private int offset;

            public boolean hasNext() { return offset < size; }

            @SuppressWarnings("unchecked")
            public T next() {
                if (expected != modCount) {
                    throw new ConcurrentModificationException();
                }
                if (offset >= size) {
                    throw new NoSuchElementException();
                }
                return (T) slots[(start + offset++) % slots.length];
            }
        };
    }
}
