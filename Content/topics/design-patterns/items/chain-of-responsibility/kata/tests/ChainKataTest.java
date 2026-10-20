import java.lang.reflect.Array;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.util.Collection;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import kata.*;

class ChainKataTest {
    static String decide(String category, long cents) {
        return new ApprovalService().approve(new Expense("ann", category, cents));
    }

    @Check(id = "small-expenses-are-automatic")
    void smallExpensesAreAutomatic() {
        Expect.equal("approved:auto", decide("meals", 10_000), "meals at 100.00");
        Expect.equal("approved:auto", decide("meals", 1), "meals at 0.01");
    }

    @Check(id = "bigger-expenses-escalate-upwards")
    void biggerExpensesEscalateUpwards() {
        Expect.equal("approved:manager", decide("travel", 10_001), "travel at 100.01");
        Expect.equal("approved:manager", decide("travel", 100_000), "travel at 1000.00");
        Expect.equal("approved:director", decide("travel", 100_001), "travel at 1000.01");
        Expect.equal("approved:director", decide("travel", 1_000_000), "travel at 10000.00");
        Expect.equal("escalate:board", decide("travel", 1_000_001), "travel above 10000.00");
    }

    @Check(id = "gifts-have-their-own-rule")
    void giftsHaveTheirOwnRule() {
        Expect.equal("approved:auto", decide("gift", 5_000), "a gift at 50.00");
        Expect.equal("rejected:policy", decide("gift", 5_001), "a gift at 50.01");
        Expect.equal("rejected:policy", decide("gift", 500_000), "an expensive gift");
    }

    @Check(id = "approver-is-a-one-method-interface", kind = Kind.DESIGN)
    void approverIsAOneMethodInterface() {
        Class<?> approver = Types.named("Approver");
        Expect.isTrue(approver.isInterface(), "Approver should be an interface");
        Method m = Types.singleAbstractMethod(approver);
        Expect.equal(Optional.class, m.getReturnType(),
            "Approver's method should return an Optional<String>: empty means pass it on");
        Expect.equal(List.of(Expense.class), List.of(m.getParameterTypes()), "its parameters");
    }

    @Check(id = "chain-runs-links-in-order", kind = Kind.DESIGN)
    void chainRunsLinksInOrder() throws Throwable {
        Class<?> approver = Types.named("Approver");
        List<String> calls = new ArrayList<>();
        Object silent = Types.implement(approver, a -> { calls.add("first"); return Optional.empty(); });
        Object answers = Types.implement(approver, a -> { calls.add("second"); return Optional.of("yes"); });
        Object never = Types.implement(approver, a -> { calls.add("third"); return Optional.of("no"); });
        Object chain = Types.create(Types.constructor(Types.named("ApprovalChain"), List.class),
            List.of(silent, answers, never));
        Method approve = Types.method(chain.getClass(), "approve", Expense.class);
        Object reply = Types.call(approve, chain, new Expense("ann", "x", 1));
        Expect.equal("yes", reply, "the first present answer wins");
        Expect.equal(List.of("first", "second"), calls, "links asked, in order, stopping at the answer");
    }

    @Check(id = "chain-falls-through-to-board", kind = Kind.DESIGN)
    void chainFallsThroughToBoard() throws Throwable {
        Object silent = Types.implement(Types.named("Approver"), a -> Optional.empty());
        Object chain = Types.create(Types.constructor(Types.named("ApprovalChain"), List.class),
            List.of(silent, silent));
        Method approve = Types.method(chain.getClass(), "approve", Expense.class);
        Expect.equal("escalate:board", Types.call(approve, chain, new Expense("ann", "x", 1)),
            "a request nobody answers");
    }

    @Check(id = "chain-does-not-know-the-rules", kind = Kind.DESIGN)
    void chainDoesNotKnowTheRules() {
        var chain = Source.type("ApprovalChain");
        Expect.none(chain.calls("cents"), "ApprovalChain reads the amount: rules belong in approvers");
        Expect.none(chain.calls("category"), "ApprovalChain reads the category");
        Expect.none(chain.comparedStrings(), "ApprovalChain compares strings to choose a rule");
        Expect.none(chain.instanceofs(), "ApprovalChain inspects the concrete approver");
    }

    @Check(id = "service-delegates-to-a-chain", kind = Kind.DESIGN)
    void serviceDelegatesToAChain() {
        Types.onlyFieldOfType(Types.named("ApprovalService"), Types.named("ApprovalChain"));
        var service = Source.type("ApprovalService");
        Expect.none(service.calls("cents"), "ApprovalService still reads the amount: let the chain decide");
        Expect.none(service.calls("category"), "ApprovalService still reads the category");
        Expect.none(service.comparedStrings(), "ApprovalService still compares strings");
    }

    @Check(id = "one-link-per-rule", kind = Kind.DESIGN)
    void oneLinkPerRule() throws Exception {
        Class<?> chainType = Types.named("ApprovalChain");
        Field holder = Types.onlyFieldOfType(Types.named("ApprovalService"), chainType);
        holder.setAccessible(true);
        Object chain = holder.get(new ApprovalService());
        int links = -1;
        for (Field f : chainType.getDeclaredFields()) {
            if (Modifier.isStatic(f.getModifiers())) continue;
            f.setAccessible(true);
            Object v = f.get(chain);
            if (v instanceof Collection<?> c) links = Math.max(links, c.size());
            else if (v != null && v.getClass().isArray()) links = Math.max(links, Array.getLength(v));
        }
        Expect.isTrue(links >= 0, "ApprovalChain should keep its approvers in a list or array field");
        Expect.isTrue(links >= 4, "ApprovalService's chain has " + links + " link(s): give the gift"
            + " rule and each approval level (auto, manager, director) its own Approver");
    }
}
