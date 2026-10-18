import java.util.List;

record Applicant(String name, int age, int income, boolean defaulted) {}

// [[spec
@FunctionalInterface
interface Spec<T> {
    boolean isSatisfiedBy(T candidate);

    default Spec<T> and(Spec<T> other) {
        return c -> isSatisfiedBy(c) && other.isSatisfiedBy(c);
    }
    default Spec<T> or(Spec<T> other) {
        return c -> isSatisfiedBy(c) || other.isSatisfiedBy(c);
    }
    default Spec<T> not() {
        return c -> !isSatisfiedBy(c);
    }
}
// ]]

// [[rules
record AtLeastAge(int years) implements Spec<Applicant> {
    public boolean isSatisfiedBy(Applicant a) { return a.age() >= years; }
}

record MinIncome(int amount) implements Spec<Applicant> {
    public boolean isSatisfiedBy(Applicant a) { return a.income() >= amount; }
}

record HasDefaulted() implements Spec<Applicant> {
    public boolean isSatisfiedBy(Applicant a) { return a.defaulted(); }
}
// ]]

class Main {
    public static void main(String[] args) {
        // [[compose
        Spec<Applicant> eligible = new AtLeastAge(18)
                .and(new MinIncome(30_000))
                .and(new HasDefaulted().not());
        // ]]
        var people = List.of(
            new Applicant("ana", 34, 52_000, false),
            new Applicant("bo", 17, 60_000, false),
            new Applicant("cy", 45, 20_000, false),
            new Applicant("di", 29, 80_000, true));
        // [[use
        for (Applicant a : people) {
            System.out.println(a.name() + ": " + eligible.isSatisfiedBy(a));
        }
        // ]]
    }
}
