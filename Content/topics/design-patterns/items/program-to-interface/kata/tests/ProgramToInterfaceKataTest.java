import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.TreeSet;
import kata.*;

class ProgramToInterfaceKataTest {
    static final List<Class<?>> CONCRETE = List.of(ArrayList.class, java.util.LinkedList.class,
        java.util.HashMap.class, java.util.TreeMap.class, java.util.LinkedHashMap.class,
        java.util.HashSet.class, java.util.TreeSet.class, java.util.LinkedHashSet.class,
        java.util.ArrayDeque.class);

    @Check(id = "total-sums")
    void totalSums() {
        ArrayList<Integer> xs = new ArrayList<>(List.of(3, 4, 5));
        Expect.equal(12, Stats.total(xs), "total of 3, 4, 5");
        Expect.equal(0, Stats.total(new ArrayList<>()), "total of nothing");
    }

    @Check(id = "lengths-maps-words")
    void lengthsMapsWords() {
        ArrayList<String> words = new ArrayList<>(List.of("kata", "ox", "kata"));
        Expect.equal(Map.of("kata", 4, "ox", 2), Stats.lengths(words), "lengths");
    }

    @Check(id = "tally-records")
    void tallyRecords() {
        Tally t = new Tally();
        t.record(2);
        t.record(7);
        Expect.equal(List.of(2, 7), List.copyOf(t.history()), "the recorded history");
    }

    /** The one-argument static method with this name; its parameter may be Collection or Iterable. */
    static Method oneArg(String name) {
        Method found = null;
        for (Method m : Types.named("Stats").getDeclaredMethods()) {
            if (m.getName().equals(name) && m.getParameterCount() == 1 && !m.isSynthetic()) {
                found = m;
            }
        }
        if (found == null) {
            Expect.fail("Stats has no one-argument method " + name);
        }
        Class<?> p = found.getParameterTypes()[0];
        Expect.isTrue(p.isInterface() && p.isAssignableFrom(TreeSet.class)
                && p.isAssignableFrom(ArrayDeque.class),
            "Stats." + name + " should take any collection (Collection or Iterable), not "
                + p.getSimpleName());
        return found;
    }

    @Check(id = "total-accepts-any-collection", kind = Kind.DESIGN)
    void totalAcceptsAnyCollection() throws Throwable {
        Method total = oneArg("total");
        Expect.equal(6, Types.call(total, null, List.of(1, 2, 3)), "total of an immutable List");
        Expect.equal(6, Types.call(total, null, new TreeSet<>(List.of(1, 2, 3))), "total of a TreeSet");
        Expect.equal(6, Types.call(total, null, new ArrayDeque<>(List.of(1, 2, 3))), "total of an ArrayDeque");
    }

    @Check(id = "lengths-accepts-any-collection", kind = Kind.DESIGN)
    void lengthsAcceptsAnyCollection() throws Throwable {
        Method lengths = oneArg("lengths");
        Expect.equal(Map.of("ab", 2, "c", 1), Types.call(lengths, null, new TreeSet<>(List.of("ab", "c"))),
            "lengths of a TreeSet");
    }

    @Check(id = "signatures-name-no-concrete-class", kind = Kind.DESIGN)
    void signaturesNameNoConcreteClass() {
        List<String> offenders = new ArrayList<>();
        for (String name : List.of("Stats", "Tally")) {
            Class<?> c = Types.named(name);
            for (Method m : c.getDeclaredMethods()) {
                if (m.isSynthetic()) {
                    continue;
                }
                if (CONCRETE.contains(m.getReturnType())) {
                    offenders.add(name + "." + m.getName() + " returns " + m.getReturnType().getSimpleName());
                }
                for (Class<?> p : m.getParameterTypes()) {
                    if (CONCRETE.contains(p)) {
                        offenders.add(name + "." + m.getName() + " takes " + p.getSimpleName());
                    }
                }
            }
            for (var f : c.getDeclaredFields()) {
                if (CONCRETE.contains(f.getType())) {
                    offenders.add(name + "." + f.getName() + " is declared as " + f.getType().getSimpleName());
                }
            }
        }
        Expect.isTrue(offenders.isEmpty(), "Declare the capability, not the class: " + offenders);
    }

    @Check(id = "lengths-returns-an-interface", kind = Kind.DESIGN)
    void lengthsReturnsAnInterface() {
        Method lengths = oneArg("lengths");
        Expect.isTrue(lengths.getReturnType().isInterface() && Map.class.isAssignableFrom(lengths.getReturnType()),
            "lengths should return Map, not " + lengths.getReturnType().getSimpleName());
        Expect.isTrue(Modifier.isStatic(lengths.getModifiers()), "lengths should stay static");
    }
}
