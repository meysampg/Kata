import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.concurrent.atomic.AtomicInteger;
import kata.*;

class ImmutableObjectKataTest {
    @Check(id = "constructor-copies-list")
    void constructorCopiesList() {
        List<String> source = new ArrayList<>(List.of("A", "B"));
        Route route = new Route("R1", source, new Date(0L));
        source.add("X");
        source.set(0, "Z");
        Expect.equal(List.of("A", "B"), route.stops(), "stops after the caller changed its list");
    }

    @Check(id = "constructor-copies-date")
    void constructorCopiesDate() {
        Date when = new Date(1000L);
        Route route = new Route("R1", List.of("A"), when);
        when.setTime(0L);
        Expect.equal(1000L, route.departure().getTime(), "departure after the caller changed its Date");
    }

    @Check(id = "stops-getter-is-safe")
    void stopsGetterIsSafe() {
        Route route = Route.sample();
        try {
            route.stops().add("X");
            route.stops().clear();
        } catch (UnsupportedOperationException expected) {
            // an unmodifiable view is as good as a copy
        }
        Expect.equal(List.of("A", "B"), route.stops(), "stops after a caller mutated what stops() returned");
    }

    @Check(id = "departure-getter-is-safe")
    void departureGetterIsSafe() {
        Route route = Route.sample();
        route.departure().setTime(5000L);
        Expect.equal(0L, route.departure().getTime(), "departure after a caller mutated what departure() returned");
    }

    @Check(id = "withers-derive-new-routes")
    void withersDeriveNewRoutes() {
        Route base = Route.sample();
        Route renamed = base.withName("R2");
        Route longer = base.withStop("C");
        Expect.equal("R2", renamed.name(), "derived name");
        Expect.equal(List.of("A", "B", "C"), longer.stops(), "derived stops");
        Expect.equal("R1", base.name(), "the base name");
        Expect.equal(List.of("A", "B"), base.stops(), "the base stops");
        Expect.equal(List.of("A", "B"), renamed.stops(), "stops carried to the renamed route");
        Expect.isTrue(renamed != base && longer != base, "a derived route should be a new object");
    }

    @Check(id = "shared-base-under-contention", timeoutMs = 5000, repeat = 5)
    void sharedBaseUnderContention() {
        Route base = Route.sample();
        AtomicInteger next = new AtomicInteger();
        List<Route> derived = Stress.race(8, () -> base.withStop("S" + next.getAndIncrement()));
        Expect.equal(List.of("A", "B"), base.stops(), "the shared base after 8 threads derived from it");
        Set<String> last = new HashSet<>();
        for (Route r : derived) {
            Expect.equal(3, r.stops().size(), "stops of a derived route");
            last.add(r.stops().get(2));
        }
        Expect.equal(8, last.size(), "distinct final stops, one per thread");
    }

    @Check(id = "all-fields-final", kind = Kind.DESIGN)
    void allFieldsFinal() {
        Class<?> route = Types.named("Route");
        Expect.isTrue(Modifier.isFinal(route.getModifiers()), "Route should be final so nobody can subclass it");
        for (Field f : route.getDeclaredFields()) {
            if (!f.isSynthetic() && !Modifier.isStatic(f.getModifiers())) {
                Expect.isTrue(Modifier.isFinal(f.getModifiers()),
                    "Route." + f.getName() + " should be final: final fields are what make publication safe");
            }
        }
    }

    @Check(id = "no-mutators", kind = Kind.DESIGN)
    void noMutators() {
        for (Method m : Types.named("Route").getDeclaredMethods()) {
            if (!m.isSynthetic() && !Modifier.isStatic(m.getModifiers())) {
                Expect.isTrue(m.getReturnType() != void.class,
                    "Route." + m.getName() + " returns void, so it can only be a mutator");
            }
        }
    }

    @Check(id = "withers-never-return-this", kind = Kind.DESIGN)
    void withersNeverReturnThis() {
        Class<?> type = Types.named("Route");
        var route = Source.type("Route");
        for (String wither : List.of("withName", "withStop")) {
            var method = route.method(wither);
            // this.field and this.method() are fine; a bare `this` is not.
            Set<String> qualified = new HashSet<>();
            List<String> members = new ArrayList<>();
            for (Field f : type.getDeclaredFields()) {
                members.add(f.getName());
            }
            for (Method m : type.getDeclaredMethods()) {
                members.add(m.getName());
            }
            for (String member : members) {
                for (Hit h : method.mentions(member)) {
                    qualified.add(h.line() + ":" + h.column());
                }
            }
            Expect.none(method.mentions("this").stream()
                .filter(h -> !qualified.contains(h.line() + ":" + h.column()))
                .toList(),
                "Route." + wither
                + " hands out this instead of building a new Route");
        }
    }
}
