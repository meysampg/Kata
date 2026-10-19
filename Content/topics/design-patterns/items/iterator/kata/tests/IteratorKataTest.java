import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.util.ArrayList;
import java.util.Collection;
import java.util.ConcurrentModificationException;
import java.util.Iterator;
import java.util.List;
import java.util.NoSuchElementException;
import kata.*;

class IteratorKataTest {
    static RingBuffer<String> buffer(int capacity, String... items) {
        var b = new RingBuffer<String>(capacity);
        for (String s : items) {
            b.add(s);
        }
        return b;
    }

    static List<String> drain(Iterable<String> source) {
        List<String> out = new ArrayList<>();
        for (String s : source) {
            out.add(s);
        }
        return out;
    }

    @Check(id = "oldest-first")
    void oldestFirst() {
        Expect.equal(List.of("a", "b"), drain(buffer(3, "a", "b")), "a half-full buffer");
        Expect.equal(2, buffer(3, "a", "b").size(), "size");
    }

    @Check(id = "wraps-when-full")
    void wrapsWhenFull() {
        var b = buffer(3, "a", "b", "c", "d", "e");
        Expect.equal(List.of("c", "d", "e"), drain(b), "after overwriting the oldest");
        Expect.equal(3, b.size(), "size stays at capacity");
        b.add("f");
        Expect.equal(List.of("d", "e", "f"), drain(b), "after one more add");
    }

    @Check(id = "empty-and-exhausted")
    void emptyAndExhausted() {
        Iterator<String> empty = buffer(2).iterator();
        Expect.isTrue(!empty.hasNext(), "an empty buffer has no next");
        Expect.raises(NoSuchElementException.class, empty::next, "next() on an empty buffer");
        Iterator<String> it = buffer(2, "a").iterator();
        it.next();
        Expect.isTrue(!it.hasNext(), "no next after the last element");
        Expect.raises(NoSuchElementException.class, it::next, "next() past the end");
    }

    @Check(id = "has-next-does-not-advance")
    void hasNextDoesNotAdvance() {
        Iterator<String> it = buffer(3, "a", "b").iterator();
        Expect.isTrue(it.hasNext() && it.hasNext() && it.hasNext(), "hasNext");
        Expect.equal("a", it.next(), "first next after hasNext calls");
    }

    @Check(id = "independent-iterators")
    void independentIterators() {
        var b = buffer(3, "a", "b", "c");
        Iterator<String> one = b.iterator();
        Iterator<String> two = b.iterator();
        Expect.equal("a", one.next(), "one, first");
        Expect.equal("a", two.next(), "two, first");
        Expect.equal("b", one.next(), "one, second");
        Expect.equal("b", two.next(), "two, second");
        Expect.equal("c", one.next(), "one, third");
    }

    @Check(id = "fail-fast")
    void failFast() {
        var b = buffer(3, "a", "b");
        Iterator<String> it = b.iterator();
        it.next();
        b.add("c");
        Expect.raises(ConcurrentModificationException.class, it::next,
            "next() after the buffer changed");
        var full = buffer(2, "a", "b");
        Iterator<String> it2 = full.iterator();
        full.add("c");
        Expect.raises(ConcurrentModificationException.class, it2::next,
            "next() after an overwrite");
    }

    @Check(id = "fresh-iterator-after-change")
    void freshIteratorAfterChange() {
        var b = buffer(2, "a", "b");
        b.iterator();
        b.add("c");
        Expect.equal(List.of("b", "c"), drain(b), "a new iterator after the change");
    }

    @Check(id = "remove-unsupported")
    void removeUnsupported() {
        Iterator<String> it = buffer(2, "a", "b").iterator();
        it.next();
        Expect.raises(UnsupportedOperationException.class, it::remove, "Iterator.remove()");
    }

    @Check(id = "buffer-is-not-its-own-cursor", kind = Kind.DESIGN)
    void bufferIsNotItsOwnCursor() {
        Class<?> type = Types.named("RingBuffer");
        Expect.isTrue(!Iterator.class.isAssignableFrom(type),
            "RingBuffer should hand out cursors, not be one");
        var b = buffer(2, "a");
        Iterator<String> one = b.iterator();
        Iterator<String> two = b.iterator();
        Expect.isTrue(one != two, "iterator() should return a new cursor every call");
        Expect.isTrue(one != (Object) b && one.getClass() != type,
            "the cursor should be its own object");
    }

    @Check(id = "storage-stays-private", kind = Kind.DESIGN)
    void storageStaysPrivate() {
        Class<?> type = Types.named("RingBuffer");
        for (Method m : type.getDeclaredMethods()) {
            if (m.isSynthetic() || Modifier.isPrivate(m.getModifiers())) {
                continue;
            }
            Class<?> r = m.getReturnType();
            Expect.isTrue(!r.isArray() && !Collection.class.isAssignableFrom(r),
                "RingBuffer." + m.getName() + " exposes its storage; callers should iterate");
        }
        for (var f : type.getDeclaredFields()) {
            Expect.isTrue(f.isSynthetic() || Modifier.isPrivate(f.getModifiers()),
                "RingBuffer." + f.getName() + " should be private");
        }
    }
}
