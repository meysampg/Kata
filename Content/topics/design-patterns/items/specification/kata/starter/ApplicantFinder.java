import java.util.ArrayList;
import java.util.List;

record Applicant(String name, int age, int income, boolean defaulted) { }

// One method per combination of rules, each with its own copy of the loop.
final class ApplicantFinder {
    private ApplicantFinder() { }

    static List<Applicant> adults(List<Applicant> all) {
        List<Applicant> out = new ArrayList<>();
        for (Applicant a : all) {
            if (a.age() >= 18) out.add(a);
        }
        return out;
    }

    static List<Applicant> adultsWithIncome(List<Applicant> all, int min) {
        List<Applicant> out = new ArrayList<>();
        for (Applicant a : all) {
            if (a.age() >= 18 && a.income() >= min) out.add(a);
        }
        return out;
    }

    static List<Applicant> adultsWithIncomeNotDefaulted(
            List<Applicant> all, int min) {
        List<Applicant> out = new ArrayList<>();
        for (Applicant a : all) {
            if (a.age() >= 18 && a.income() >= min && !a.defaulted()) {
                out.add(a);
            }
        }
        return out;
    }

    static List<Applicant> withIncomeNotDefaulted(
            List<Applicant> all, int min) {
        List<Applicant> out = new ArrayList<>();
        for (Applicant a : all) {
            if (a.income() >= min && !a.defaulted()) out.add(a);
        }
        return out;
    }

    static List<Applicant> defaultedAdults(List<Applicant> all) {
        List<Applicant> out = new ArrayList<>();
        for (Applicant a : all) {
            if (a.age() >= 18 && a.defaulted()) out.add(a);
        }
        return out;
    }
}
