import java.lang.reflect.Method;
import java.util.function.Function;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import kata.*;

class SpecificationKataTest {
    static final Applicant ANA = new Applicant("ana", 34, 52_000, false);
    static final Applicant BO = new Applicant("bo", 17, 60_000, false);
    static final Applicant CY = new Applicant("cy", 45, 20_000, false);
    static final Applicant DI = new Applicant("di", 29, 80_000, true);
    static final Applicant EVE = new Applicant("eve", 18, 30_000, false);
    static final List<Applicant> ALL = List.of(ANA, BO, CY, DI, EVE);

    static List<String> names(List<Applicant> found) {
        return found.stream().map(Applicant::name).toList();
    }

    static Object rule(Class<?> spec, Function<Object, Boolean> fn) {
        return Types.implement(spec, args -> fn.apply(args[0]));
    }

    @Check(id = "adult-rules")
    void adultRules() {
        Expect.equal(List.of("ana", "cy", "di", "eve"), names(ApplicantFinder.adults(ALL)), "adults");
        Expect.equal(List.of("ana", "di", "eve"),
            names(ApplicantFinder.adultsWithIncome(ALL, 30_000)), "adultsWithIncome(30000)");
    }

    @Check(id = "default-rules")
    void defaultRules() {
        Expect.equal(List.of("ana", "eve"),
            names(ApplicantFinder.adultsWithIncomeNotDefaulted(ALL, 30_000)),
            "adultsWithIncomeNotDefaulted(30000)");
        Expect.equal(List.of("ana", "bo", "eve"),
            names(ApplicantFinder.withIncomeNotDefaulted(ALL, 30_000)),
            "withIncomeNotDefaulted(30000)");
        Expect.equal(List.of("di"), names(ApplicantFinder.defaultedAdults(ALL)), "defaultedAdults");
    }

    @Check(id = "spec-interface", kind = Kind.DESIGN)
    void specInterface() {
        Class<?> spec = Types.named("Spec");
        Expect.isTrue(spec.isInterface(), "Spec should be an interface");
        Expect.isTrue(spec.getTypeParameters().length == 1, "Spec should be generic: Spec<T>");
        Method test = Types.singleAbstractMethod(spec);
        Expect.equal("isSatisfiedBy", test.getName(), "Spec's one abstract method");
        Expect.equal(boolean.class, test.getReturnType(), "isSatisfiedBy's return type");
    }

    @Check(id = "specs-combine", kind = Kind.DESIGN)
    void specsCombine() throws Throwable {
        Class<?> spec = Types.named("Spec");
        Object even = rule(spec, a -> ((Integer) a) % 2 == 0);
        Object big = rule(spec, a -> ((Integer) a) > 10);
        Method test = Types.method(spec, "isSatisfiedBy", Object.class);
        Object both = Types.call(Types.method(spec, "and", spec), even, big);
        Object either = Types.call(Types.method(spec, "or", spec), even, big);
        Object notEven = Types.call(Types.method(spec, "not"), even);
        Expect.equal(List.of(false, true, false, true),
            List.of(Types.call(test, both, 3), Types.call(test, both, 12),
                    Types.call(test, both, 8), Types.call(test, either, 8)),
            "and / or on 3, 12, 8 and 8");
        Expect.equal(List.of(true, false), List.of(
            Types.call(test, notEven, 3), Types.call(test, notEven, 4)), "not");
    }

    @Check(id = "rule-factories", kind = Kind.DESIGN)
    void ruleFactories() throws Throwable {
        Class<?> spec = Types.named("Spec");
        Class<?> specs = Types.named("Specs");
        Method test = Types.method(spec, "isSatisfiedBy", Object.class);
        Object age = Types.call(Types.staticMethod(specs, "atLeastAge", int.class), null, 18);
        Object income = Types.call(Types.staticMethod(specs, "minIncome", int.class), null, 30_000);
        Object defaulted = Types.call(Types.staticMethod(specs, "defaulted"), null);
        Expect.equal(List.of(true, false), List.of(
            Types.call(test, age, EVE), Types.call(test, age, BO)), "atLeastAge(18) on 18 and 17");
        Expect.equal(List.of(true, false), List.of(
            Types.call(test, income, EVE), Types.call(test, income, CY)),
            "minIncome(30000) on 30000 and 20000");
        Expect.equal(List.of(true, false), List.of(
            Types.call(test, defaulted, DI), Types.call(test, defaulted, ANA)), "defaulted()");
    }

    @Check(id = "finder-takes-any-spec", kind = Kind.DESIGN)
    void finderTakesAnySpec() throws Throwable {
        Class<?> spec = Types.named("Spec");
        Object startsWithB = rule(spec, a -> ((Applicant) a).name().startsWith("b"));
        Method find = Types.staticMethod(ApplicantFinder.class, "find", List.class, spec);
        Expect.equal(List.of("bo"), names((List<Applicant>) Types.call(find, null, ALL, startsWithB)),
            "find with a rule written just now");
    }

    static final List<String> OLD = List.of("adults", "adultsWithIncome",
        "adultsWithIncomeNotDefaulted", "withIncomeNotDefaulted", "defaultedAdults");

    @Check(id = "finders-delegate", kind = Kind.DESIGN)
    void findersDelegate() {
        var finder = Source.type("ApplicantFinder");
        // Methods of ApplicantFinder that run the one search: find itself, or a helper calling it.
        Set<String> searches = new HashSet<>(Set.of("find"));
        for (Method m : ApplicantFinder.class.getDeclaredMethods()) {
            String n = m.getName();
            if (!OLD.contains(n) && !n.startsWith("lambda$")
                    && !finder.method(n).calls("find").isEmpty()) {
                searches.add(n);
            }
        }
        for (String m : OLD) {
            var body = finder.method(m);
            Expect.isTrue(searches.stream().anyMatch(s -> !body.calls(s).isEmpty()),
                "ApplicantFinder." + m + " should build a Spec and pass it to find(...)");
            Expect.none(body.calls("age"), "ApplicantFinder." + m + " still tests the age itself");
            Expect.none(body.calls("income"), "ApplicantFinder." + m + " still tests the income itself");
            Expect.none(body.calls("add"), "ApplicantFinder." + m + " still copies its own loop");
        }
    }
}
