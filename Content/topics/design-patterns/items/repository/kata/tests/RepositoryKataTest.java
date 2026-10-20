import java.lang.reflect.Field;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import kata.*;

class RepositoryKataTest {
    static Order order(String id, String customer, int cents) {
        return new Order(new OrderId(id), customer, cents);
    }

    static OrderRepository repo() {
        return new InMemoryOrderRepository();
    }

    @Check(id = "save-and-find")
    void saveAndFind() {
        OrderRepository r = repo();
        r.save(order("o-1", "ada", 2550));
        Expect.equal(Optional.of(order("o-1", "ada", 2550)),
            r.findById(new OrderId("o-1")), "findById after save");
    }

    @Check(id = "missing-is-empty")
    void missingIsEmpty() {
        Expect.equal(Optional.empty(), repo().findById(new OrderId("nope")),
            "findById of an unknown id");
        Expect.equal(List.of(), repo().findByCustomer("nobody"),
            "findByCustomer of an unknown customer");
        repo().save(order("x-1", "ada", 1));
        Expect.equal(Optional.empty(), repo().findById(new OrderId("x-1")),
            "a fresh repository asked for an order saved in another one (is the store static?)");
    }

    @Check(id = "save-replaces")
    void saveReplaces() {
        OrderRepository r = repo();
        r.save(order("o-1", "ada", 100));
        r.save(order("o-1", "ada", 900));
        Expect.equal(900, r.findById(new OrderId("o-1")).orElseThrow().totalCents(),
            "total after saving the same id twice");
        Expect.equal(1, r.findByCustomer("ada").size(), "orders kept for ada");
    }

    @Check(id = "by-customer-sorted")
    void byCustomerSorted() {
        OrderRepository r = repo();
        r.save(order("o-3", "ada", 1));
        r.save(order("o-1", "ada", 2));
        r.save(order("o-2", "bob", 3));
        r.save(order("o-10", "ada", 4));
        List<String> ids = r.findByCustomer("ada").stream()
            .map(o -> o.id().value()).toList();
        Expect.equal(List.of("o-1", "o-10", "o-3"), ids,
            "ada's orders, sorted by id text");
    }

    @Check(id = "remove")
    void remove() {
        OrderRepository r = repo();
        r.save(order("o-1", "ada", 1));
        r.remove(new OrderId("o-1"));
        r.remove(new OrderId("never-there"));
        Expect.equal(Optional.empty(), r.findById(new OrderId("o-1")),
            "findById after remove");
        Expect.equal(List.of(), r.findByCustomer("ada"), "ada's orders after remove");
    }

    @Check(id = "results-are-snapshots")
    void resultsAreSnapshots() {
        OrderRepository r = repo();
        r.save(order("o-1", "ada", 1));
        List<Order> before = r.findByCustomer("ada");
        r.save(order("o-2", "ada", 2));
        Expect.equal(1, before.size(), "a list returned earlier must not change later");
    }

    @Check(id = "service-works-with-any-port")
    void serviceWorksWithAnyPort() {
        List<Order> stored = List.of(order("a", "ada", 2550), order("b", "ada", 1000));
        OrderRepository fake = new OrderRepository() {
            public Optional<Order> findById(OrderId id) { return Optional.empty(); }
            public List<Order> findByCustomer(String c) { return new ArrayList<>(stored); }
            public void save(Order o) { }
            public void remove(OrderId id) { }
        };
        Expect.equal(35, new LoyaltyService(fake).points("ada"),
            "points computed from a repository it has never seen");
    }

    @Check(id = "loyalty-over-memory-repo")
    void loyaltyOverMemoryRepo() {
        OrderRepository r = repo();
        r.save(order("o-1", "ada", 2550));
        r.save(order("o-2", "bob", 900));
        r.save(order("o-3", "ada", 1000));
        Expect.equal(35, new LoyaltyService(r).points("ada"), "ada's points");
        Expect.equal(0, new LoyaltyService(r).points("eve"), "eve's points");
    }

    @Check(id = "memory-repo-implements-port", kind = Kind.DESIGN)
    void memoryRepoImplementsPort() {
        Class<?> port = Types.named("OrderRepository");
        Class<?> memory = Types.named("InMemoryOrderRepository");
        Expect.isTrue(port.isInterface(), "OrderRepository should stay an interface");
        Expect.isTrue(port.isAssignableFrom(memory),
            "InMemoryOrderRepository should implement OrderRepository");
    }

    @Check(id = "service-depends-on-port", kind = Kind.DESIGN)
    void serviceDependsOnPort() {
        Class<?> service = Types.named("LoyaltyService");
        Class<?> port = Types.named("OrderRepository");
        Field f = Types.onlyFieldOfType(service, port);
        Expect.isTrue(java.lang.reflect.Modifier.isFinal(f.getModifiers()),
            "LoyaltyService." + f.getName() + " should be final");
        var shape = Source.type("LoyaltyService");
        Expect.none(shape.mentions("InMemoryOrderRepository"),
            "LoyaltyService names the in-memory store");
        Expect.none(shape.news("InMemoryOrderRepository"),
            "LoyaltyService builds its own store");
    }
}
