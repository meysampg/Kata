import java.util.List;
import java.util.Optional;

record Expense(String employee, String category, long cents) { }

// One link: answer, or stay silent so the next link can try.
interface Approver {
    Optional<String> decide(Expense e);
}

final class ApprovalChain {
    private final List<Approver> approvers;

    ApprovalChain(List<Approver> approvers) {
        this.approvers = List.copyOf(approvers);
    }

    String approve(Expense e) {
        for (Approver a : approvers) {
            Optional<String> decision = a.decide(e);
            if (decision.isPresent()) return decision.get();
        }
        return "escalate:board";
    }
}

final class Approvals {
    private Approvals() { }

    static Approver upTo(long cents, String who) {
        return e -> e.cents() <= cents
            ? Optional.of("approved:" + who) : Optional.empty();
    }

    static ApprovalChain standard() {
        Approver gifts = e -> !e.category().equals("gift")
            ? Optional.empty()
            : Optional.of(e.cents() > 5_000
                ? "rejected:policy" : "approved:auto");
        return new ApprovalChain(List.of(gifts,
            upTo(10_000, "auto"),
            upTo(100_000, "manager"),
            upTo(1_000_000, "director")));
    }
}

final class ApprovalService {
    private final ApprovalChain chain = Approvals.standard();

    String approve(Expense e) { return chain.approve(e); }
}
