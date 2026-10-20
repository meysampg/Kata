import java.lang.reflect.Constructor;
import java.lang.reflect.Field;
import java.lang.reflect.Modifier;
import java.util.ArrayList;
import java.util.List;
import kata.*;

class DecoratorKataTest {
    static List<String> sendVia(String tag, boolean shout, String msg) {
        List<String> out = new ArrayList<>();
        Notifiers.create(tag, shout, out).send(msg);
        return out;
    }

    static Notifier wrap(String type, Notifier next) throws Throwable {
        Class<?> c = Types.named(type);
        if (type.equals("Prefixing")) {
            return (Notifier) Types.create(Types.constructor(c, Notifier.class, String.class), next, "T");
        }
        return (Notifier) Types.create(Types.constructor(c, Notifier.class), next);
    }

    @Check(id = "plain")
    void plain() {
        Expect.equal(List.of("disk 91%"), sendVia(null, false, "disk 91%"), "no options");
    }

    @Check(id = "prefix-only")
    void prefixOnly() {
        Expect.equal(List.of("[ops] disk 91%"), sendVia("ops", false, "disk 91%"), "a tag");
    }

    @Check(id = "shout-only")
    void shoutOnly() {
        Expect.equal(List.of("DISK 91%"), sendVia(null, true, "disk 91%"), "shout");
    }

    @Check(id = "shout-and-prefix")
    void shoutAndPrefix() {
        Expect.equal(List.of("[ops] DISK 91%"), sendVia("ops", true, "disk 91%"),
            "a tag and shout (the tag keeps its case)");
    }

    @Check(id = "decorators-wrap-a-notifier", kind = Kind.DESIGN)
    void decoratorsWrapANotifier() {
        for (String name : List.of("Prefixing", "Shouting")) {
            Class<?> c = Types.named(name);
            Expect.isTrue(Notifier.class.isAssignableFrom(c), name + " should implement Notifier");
            Field f = wrappedField(c);
            Expect.isTrue(Modifier.isFinal(f.getModifiers()),
                name + "." + f.getName() + " should be final");
        }
        Types.constructor(Types.named("Prefixing"), Notifier.class, String.class);
        Types.constructor(Types.named("Shouting"), Notifier.class);
    }

    @Check(id = "no-combination-classes", kind = Kind.DESIGN)
    void noCombinationClasses() {
        for (String old : List.of("PrefixedListNotifier", "ShoutingListNotifier",
                "ShoutingPrefixedListNotifier", "ListNotifierBase")) {
            boolean exists;
            try {
                Types.named(old);
                exists = true;
            } catch (CheckFailure e) {
                exists = false;
            }
            Expect.isTrue(!exists, old + " is still there: one class per combination does not scale");
        }
        for (Class<?> c : userClasses()) {
            if (!Notifier.class.isAssignableFrom(c) || c.isInterface() || c == ListNotifier.class) {
                continue;
            }
            for (Class<?> k = c; k != null && k != Object.class; k = k.getSuperclass()) {
                Expect.isTrue(Types.fieldsOfType(k, List.class).isEmpty(),
                    c.getSimpleName() + " stores messages itself; only ListNotifier should, "
                        + "and every option should wrap another Notifier");
            }
        }
    }

    /** The final Notifier field a decorator forwards to, declared in it or a superclass. */
    static Field wrappedField(Class<?> c) {
        List<Field> found = new ArrayList<>();
        for (Class<?> k = c; k != null && k != Object.class; k = k.getSuperclass()) {
            found.addAll(Types.fieldsOfType(k, Notifier.class));
        }
        Expect.isTrue(found.size() == 1, c.getSimpleName()
            + " should hold exactly one Notifier to forward to, but has " + found.size());
        return found.get(0);
    }

    /** Every class compiled from the learner's files (the tests' classes excluded). */
    static List<Class<?>> userClasses() {
        try {
            ClassLoader loader = Notifier.class.getClassLoader();
            java.nio.file.Path dir = java.nio.file.Path.of(
                loader.getResource("DecoratorKataTest.class").toURI()).getParent();
            List<Class<?>> out = new ArrayList<>();
            try (var files = java.nio.file.Files.list(dir)) {
                for (var f : (Iterable<java.nio.file.Path>) files::iterator) {
                    String n = f.getFileName().toString();
                    if (n.endsWith(".class") && !n.startsWith("DecoratorKataTest")) {
                        out.add(Class.forName(n.substring(0, n.length() - 6), false, loader));
                    }
                }
            }
            return out;
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }

    @Check(id = "stack-in-any-order", kind = Kind.DESIGN)
    void stackInAnyOrder() throws Throwable {
        List<String> a = new ArrayList<>();
        wrap("Shouting", wrap("Prefixing", new ListNotifier(a))).send("hi");
        Expect.equal(List.of("[T] HI"), a, "Shouting around Prefixing");
        List<String> b = new ArrayList<>();
        wrap("Prefixing", wrap("Shouting", new ListNotifier(b))).send("hi");
        Expect.equal(List.of("[T] HI"), b, "Prefixing around Shouting");
        List<String> c = new ArrayList<>();
        wrap("Shouting", wrap("Shouting", new ListNotifier(c))).send("hi");
        Expect.equal(List.of("HI"), c, "a decorator applied twice");
    }

    @Check(id = "wraps-any-notifier", kind = Kind.DESIGN)
    void wrapsAnyNotifier() throws Throwable {
        List<String> seen = new ArrayList<>();
        Notifier custom = m -> seen.add("custom:" + m);
        wrap("Prefixing", custom).send("x");
        wrap("Shouting", custom).send("y");
        Expect.equal(List.of("custom:[T] x", "custom:Y"), seen,
            "decorators around a Notifier they have never seen");
    }

    @Check(id = "create-does-not-branch-on-combos", kind = Kind.DESIGN)
    void createDoesNotBranchOnCombos() {
        var create = Source.type("Notifiers").method("create");
        Expect.atMost(1, create.news("ListNotifier"),
            "Notifiers.create builds the base in more than one place; build it once and wrap it");
        Expect.atMost(1, create.news("Prefixing"),
            "Notifiers.create builds Prefixing in more than one place (one branch per combination?)");
        Expect.atMost(1, create.news("Shouting"),
            "Notifiers.create builds Shouting in more than one place (one branch per combination?)");
        Expect.none(create.news("ListNotifierBase"), "Notifiers.create still builds a combination class");
    }
}
