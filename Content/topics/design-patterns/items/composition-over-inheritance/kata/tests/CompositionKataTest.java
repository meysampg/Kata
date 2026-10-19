import java.util.List;
import java.util.Set;
import java.util.TreeSet;
import kata.*;

class CompositionKataTest {
    @Check(id = "add-counts-each-offer")
    void addCountsEachOffer() {
        CountingSet<String> s = new CountingSet<>();
        s.add("a");
        s.add("a");
        s.add("b");
        Expect.equal(3, s.added(), "added() after three adds, one of them a duplicate");
        Expect.equal(2, s.size(), "size after the same adds");
    }

    @Check(id = "add-all-counts-once")
    void addAllCountsOnce() {
        CountingSet<String> s = new CountingSet<>();
        s.addAll(List.of("a", "b"));
        Expect.equal(2, s.added(), "added() after addAll of two elements");
        s.addAll(List.of("b", "c", "d"));
        Expect.equal(5, s.added(), "added() after a second addAll of three, one a duplicate");
    }

    @Check(id = "still-a-set")
    void stillASet() {
        Set<String> s = new CountingSet<>();
        s.addAll(List.of("a", "b"));
        Expect.isTrue(s.contains("a") && !s.contains("z"), "contains");
        Expect.isTrue(s.remove("a") && s.size() == 1, "remove");
        s.clear();
        Expect.isTrue(s.isEmpty(), "clear");
        Expect.equal(Set.of(), s, "equality with an empty set");
    }

    @Check(id = "no-hashset-inheritance", kind = Kind.DESIGN)
    void noHashsetInheritance() {
        Class<?> c = Types.named("CountingSet");
        Expect.isTrue(!java.util.HashSet.class.isAssignableFrom(c),
            "CountingSet still extends HashSet, so it inherits how HashSet implements addAll");
    }

    @Check(id = "wraps-any-set", kind = Kind.DESIGN)
    void wrapsAnySet() throws Throwable {
        Class<?> c = Types.named("CountingSet");
        Set<String> tree = new TreeSet<>();
        Object wrapper = Types.create(Types.constructor(c, Set.class), tree);
        @SuppressWarnings("unchecked")
        Set<String> s = (Set<String>) wrapper;
        s.addAll(List.of("b", "a"));
        Expect.equal(Set.of("a", "b"), tree, "the wrapped set should receive the elements");
        Expect.equal(List.of("a", "b"), List.copyOf(s), "iteration should follow the wrapped TreeSet");
    }
}
