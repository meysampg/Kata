import java.util.AbstractSet;
import java.util.Collection;
import java.util.HashSet;
import java.util.Iterator;
import java.util.Set;

final class CountingSet<E> extends AbstractSet<E> {
    private final Set<E> inner;
    private int added;

    CountingSet() { this(new HashSet<>()); }

    CountingSet(Set<E> inner) { this.inner = inner; }

    @Override public boolean add(E e) {
        added++;
        return inner.add(e);
    }

    @Override public boolean addAll(Collection<? extends E> c) {
        boolean changed = false;
        for (E e : c) {
            changed |= add(e);
        }
        return changed;
    }

    @Override public boolean remove(Object o) { return inner.remove(o); }
    @Override public boolean contains(Object o) { return inner.contains(o); }
    @Override public void clear() { inner.clear(); }
    @Override public int size() { return inner.size(); }
    @Override public Iterator<E> iterator() { return inner.iterator(); }

    int added() { return added; }
}
