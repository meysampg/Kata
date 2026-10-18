import java.util.Collection;
import java.util.HashSet;
import java.util.Iterator;
import java.util.List;
import java.util.Set;

// [[before
@SuppressWarnings("serial")
class CountingSetBefore<E> extends HashSet<E> {
    private int added;
    @Override public boolean add(E e) { added++; return super.add(e); }
    @Override public boolean addAll(Collection<? extends E> c) {
        added += c.size();                   // HashSet.addAll calls add() too
        return super.addAll(c);
    }
    int added() { return added; }
}
// ]]

final class CountingSet<E> implements Set<E> {
    // [[count
    private final Set<E> inner;               // has-a, not is-a
    private int added;

    CountingSet(Set<E> inner) { this.inner = inner; }

    public boolean add(E e) { added++; return inner.add(e); }
    public boolean addAll(Collection<? extends E> c) {
        boolean changed = false;
        for (E e : c) changed |= add(e);      // our own, known path
        return changed;
    }
    int added() { return added; }
    // ]]
    // [[forward
    public int size() { return inner.size(); }
    public boolean isEmpty() { return inner.isEmpty(); }
    public boolean contains(Object o) { return inner.contains(o); }
    public Iterator<E> iterator() { return inner.iterator(); }
    public Object[] toArray() { return inner.toArray(); }
    public <T> T[] toArray(T[] a) { return inner.toArray(a); }
    public boolean remove(Object o) { return inner.remove(o); }
    public boolean containsAll(Collection<?> c) { return inner.containsAll(c); }
    public boolean retainAll(Collection<?> c) { return inner.retainAll(c); }
    public boolean removeAll(Collection<?> c) { return inner.removeAll(c); }
    public void clear() { inner.clear(); }
    // ]]
}

class Main {
    public static void main(String[] args) {
        // [[client
        var before = new CountingSetBefore<String>();
        before.addAll(List.of("a", "b", "c"));
        System.out.println("inheritance: " + before.added());

        var after = new CountingSet<>(new HashSet<String>());
        after.addAll(List.of("a", "b", "c"));
        System.out.println("composition: " + after.added());
        // ]]
    }
}
