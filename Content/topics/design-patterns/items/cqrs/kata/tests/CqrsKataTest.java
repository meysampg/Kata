import java.lang.reflect.Constructor;
import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.util.ArrayList;
import java.util.List;
import kata.*;

class CqrsKataTest {
    static Shop shop() {
        Shop s = new Shop();
        s.place("o1", "ada", 1500);
        s.place("o2", "bob", 700);
        s.place("o3", "ada", 1000);
        return s;
    }

    @Check(id = "revenue-per-customer")
    void revenuePerCustomer() {
        Shop s = shop();
        Expect.equal(2500, s.revenue("ada"), "ada's revenue");
        Expect.equal(700, s.revenue("bob"), "bob's revenue");
        Expect.equal(0, s.revenue("nobody"), "an unknown customer's revenue");
    }

    @Check(id = "top-ranking")
    void topRanking() {
        Shop s = shop();
        s.place("o4", "cy", 700);
        Expect.equal(List.of("ada=2500", "bob=700"), s.top(2), "top 2, ties by name");
        Expect.equal(List.of("ada=2500", "bob=700", "cy=700"), s.top(10), "top 10");
    }

    @Check(id = "duplicate-order-rejected")
    void duplicateOrderRejected() {
        Shop s = shop();
        var e = Expect.raises(IllegalStateException.class,
            () -> s.place("o1", "eve", 100), "placing order o1 twice");
        Expect.isTrue(String.valueOf(e.getMessage()).contains("o1"), "the message should name o1");
        Expect.equal(0, s.revenue("eve"), "revenue of the rejected order");
    }

    @Check(id = "bad-amount-rejected")
    void badAmountRejected() {
        Shop s = shop();
        Expect.raises(IllegalArgumentException.class, () -> s.place("o9", "eve", 0), "amount 0");
        Expect.raises(IllegalArgumentException.class, () -> s.place("o9", "eve", -5), "amount -5");
        s.place("o9", "eve", 100);
        Expect.equal(100, s.revenue("eve"), "o9 can be placed once it is valid");
    }

    @Check(id = "write-side-exists", kind = Kind.DESIGN)
    void writeSideExists() throws Throwable {
        Class<?> commands = Types.named("OrderCommands");
        Object c = Types.create(Types.constructor(commands));
        Types.call(Types.method(commands, "handle", PlaceOrder.class), c, new PlaceOrder("a", "ada", 5));
        List<?> feed = (List<?>) Types.call(Types.method(commands, "feed"), c);
        Expect.equal(List.of(new OrderPlaced("a", "ada", 5)), feed, "the feed after one command");
    }

    @Check(id = "write-side-answers-no-queries", kind = Kind.DESIGN)
    void writeSideAnswersNoQueries() {
        Class<?> commands = Types.named("OrderCommands");
        for (Method m : commands.getDeclaredMethods()) {
            if (Modifier.isPrivate(m.getModifiers()) || m.isSynthetic()) continue;
            boolean feed = m.getName().equals("feed");
            Expect.isTrue(feed || m.getReturnType() == void.class,
                "OrderCommands." + m.getName() + " returns data; queries belong on the read side");
        }
    }

    @Check(id = "view-needs-only-events", kind = Kind.DESIGN)
    void viewNeedsOnlyEvents() throws Throwable {
        Class<?> view = Types.named("RevenueView");
        Object v = Types.create(Types.constructor(view));
        Method catchUp = Types.method(view, "catchUp", List.class);
        var feed = new ArrayList<OrderPlaced>();
        feed.add(new OrderPlaced("a", "ada", 5));
        Types.call(catchUp, v, feed);
        Types.call(catchUp, v, feed);
        feed.add(new OrderPlaced("b", "ada", 7));
        Types.call(catchUp, v, feed);
        Expect.equal(12, Types.call(Types.method(view, "revenue", String.class), v, "ada"),
            "revenue after catching up three times over a growing feed");
    }

    @Check(id = "view-does-not-reach-the-write-side", kind = Kind.DESIGN)
    void viewDoesNotReachTheWriteSide() {
        var view = Source.type("RevenueView");
        Expect.none(view.mentions("OrderCommands"), "RevenueView reaches into OrderCommands");
        Expect.none(view.mentions("PlaceOrder"), "RevenueView depends on commands");
        Expect.isTrue(Types.fieldsOfType(Types.named("RevenueView"), Types.named("OrderCommands")).isEmpty(),
            "RevenueView holds the write side");
    }

    @Check(id = "shop-only-wires", kind = Kind.DESIGN)
    void shopOnlyWires() {
        Class<?> shop = Types.named("Shop");
        for (var f : shop.getDeclaredFields()) {
            Expect.isTrue(!java.util.Map.class.isAssignableFrom(f.getType())
                    && !java.util.Collection.class.isAssignableFrom(f.getType()),
                "Shop." + f.getName() + " keeps data itself; it should only wire the two sides");
        }
    }
}
