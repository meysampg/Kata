import java.util.List;

record Applicant(String name, int age, int income, boolean defaulted) { }

// One generic search; the old entry points are just named combinations.
final class ApplicantFinder {
    private ApplicantFinder() { }

    static List<Applicant> find(List<Applicant> all, Spec<Applicant> spec) {
        return all.stream().filter(spec::isSatisfiedBy).toList();
    }

    static List<Applicant> adults(List<Applicant> all) {
        return find(all, Specs.atLeastAge(18));
    }

    static List<Applicant> adultsWithIncome(List<Applicant> all, int min) {
        return find(all, Specs.atLeastAge(18).and(Specs.minIncome(min)));
    }

    static List<Applicant> adultsWithIncomeNotDefaulted(
            List<Applicant> all, int min) {
        return find(all, Specs.atLeastAge(18).and(Specs.minIncome(min))
            .and(Specs.defaulted().not()));
    }

    static List<Applicant> withIncomeNotDefaulted(
            List<Applicant> all, int min) {
        return find(all, Specs.minIncome(min).and(Specs.defaulted().not()));
    }

    static List<Applicant> defaultedAdults(List<Applicant> all) {
        return find(all, Specs.atLeastAge(18).and(Specs.defaulted()));
    }
}
