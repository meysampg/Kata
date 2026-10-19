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

final class Specs {
    private Specs() { }

    static Spec<Applicant> atLeastAge(int years) {
        return a -> a.age() >= years;
    }

    static Spec<Applicant> minIncome(int amount) {
        return a -> a.income() >= amount;
    }

    static Spec<Applicant> defaulted() {
        return Applicant::defaulted;
    }
}
