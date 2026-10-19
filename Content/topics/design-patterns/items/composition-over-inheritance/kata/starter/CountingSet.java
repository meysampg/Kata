import java.util.Collection;
import java.util.HashSet;

// Counts every element offered to the set, so the metrics can chart traffic.
// Bug: addAll(List.of("a", "b")) reports 4.
@SuppressWarnings("serial")
class CountingSet<E> extends HashSet<E> {
    private int added;

    @Override public boolean add(E e) {
        added++;
        return super.add(e);
    }

    @Override public boolean addAll(Collection<? extends E> c) {
        added += c.size();
        return super.addAll(c);
    }

    int added() { return added; }
}
