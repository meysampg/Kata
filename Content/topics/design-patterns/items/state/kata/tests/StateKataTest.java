import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.util.HashSet;
import java.util.Set;
import kata.*;

class StateKataTest {
    static Order paid() {
        Order o = new Order();
        o.pay("R-1");
        return o;
    }

    static void rejects(Runnable event, Order o, String what) {
        String before = o.describe();
        Expect.raises(IllegalStateException.class, event::run, what);
        Expect.equal(before, o.describe(), what + " must leave the order as it was");
    }

    @Check(id = "happy-path")
    void happyPath() {
        Order o = new Order();
        Expect.equal("New", o.describe(), "a fresh order");
        o.pay("R-1");
        Expect.equal("Paid[R-1]", o.describe(), "after pay");
        o.ship("TRK-9");
        Expect.equal("Shipped[TRK-9]", o.describe(), "after ship");
    }

    @Check(id = "cancel-before-shipping")
    void cancelBeforeShipping() {
        Order fresh = new Order();
        fresh.cancel();
        Expect.equal("Cancelled", fresh.describe(), "cancelling a new order");
        Order paid = paid();
        paid.cancel();
        Expect.equal("Cancelled", paid.describe(), "cancelling a paid order");
    }

    @Check(id = "illegal-events-rejected")
    void illegalEventsRejected() {
        Order fresh = new Order();
        rejects(() -> fresh.ship("T"), fresh, "ship on a new order");
        Order paid = paid();
        rejects(() -> paid.pay("R-2"), paid, "paying twice");
        Order shipped = paid();
        shipped.ship("T");
        rejects(() -> shipped.cancel(), shipped, "cancel after shipping");
        rejects(() -> shipped.pay("R"), shipped, "pay after shipping");
        rejects(() -> shipped.ship("T2"), shipped, "shipping twice");
    }

    @Check(id = "cancelled-is-final")
    void cancelledIsFinal() {
        Order o = paid();
        o.cancel();
        rejects(() -> o.cancel(), o, "cancelling twice");
        rejects(() -> o.pay("R"), o, "pay after cancel");
        rejects(() -> o.ship("T"), o, "ship after cancel");
    }

    @Check(id = "state-interface", kind = Kind.DESIGN)
    void stateInterface() {
        Class<?> state = Types.named("OrderState");
        Expect.isTrue(state.isInterface(), "OrderState should be an interface");
        for (String[] event : new String[][] {{"pay"}, {"ship"}}) {
            Method m = Types.method(state, event[0], String.class);
            Expect.equal(state, m.getReturnType(), "return type of OrderState." + event[0]);
        }
        Method cancel = Types.method(state, "cancel");
        Expect.equal(state, cancel.getReturnType(), "OrderState.cancel's return type");
    }

    @Check(id = "order-holds-one-state", kind = Kind.DESIGN)
    void orderHoldsOneState() {
        Class<?> state = Types.named("OrderState");
        Class<?> order = Types.named("Order");
        Field f = Types.onlyFieldOfType(order, state);
        Expect.isTrue(Modifier.isPrivate(f.getModifiers()), "Order." + f.getName() + " should be private");
        for (Field other : order.getDeclaredFields()) {
            Expect.isTrue(!other.getType().isEnum(),
                "Order still keeps a status enum in " + other.getName());
        }
        Expect.isTrue(Types.fieldsOfType(order, String.class).isEmpty(),
            "Order should not keep the receipt or tracking itself; they belong to the states that have them");
    }

    @Check(id = "order-does-not-branch", kind = Kind.DESIGN)
    void orderDoesNotBranch() {
        var order = Source.type("Order");
        Expect.none(order.switches(), "Order still switches on its status");
        Expect.none(order.instanceofs(), "Order inspects the concrete state");
        Expect.none(order.mentions("Status"), "Order still refers to the Status enum");
    }

    @Check(id = "one-class-per-phase", kind = Kind.DESIGN)
    void oneClassPerPhase() throws Throwable {
        Field f = Types.onlyFieldOfType(Types.named("Order"), Types.named("OrderState"));
        Set<Class<?>> seen = new HashSet<>();
        Order o = new Order();
        seen.add(f.get(o).getClass());
        o.pay("R-1");
        seen.add(f.get(o).getClass());
        o.ship("TRK-9");
        seen.add(f.get(o).getClass());
        Order cancelled = new Order();
        cancelled.cancel();
        seen.add(f.get(cancelled).getClass());
        Expect.equal(4, seen.size(), "state classes for New, Paid, Shipped and Cancelled");
    }
}
