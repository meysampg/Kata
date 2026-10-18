import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

// [[domain
record OrderId(String value) {}

record Order(OrderId id, String customer, int totalCents) {}
// ]]

// [[port
interface OrderRepository {
    Optional<Order> findById(OrderId id);
    List<Order> findByCustomer(String customer);
    void save(Order order);
}
// ]]

// [[memory
final class InMemoryOrderRepository implements OrderRepository {
    private final Map<OrderId, Order> rows = new ConcurrentHashMap<>();

    public Optional<Order> findById(OrderId id) {
        return Optional.ofNullable(rows.get(id));
    }

    public List<Order> findByCustomer(String customer) {
        return rows.values().stream()
            .filter(o -> o.customer().equals(customer))
            .sorted(Comparator.comparing(o -> o.id().value()))
            .toList();
    }

    public void save(Order order) { rows.put(order.id(), order); }
}
// ]]

// [[service
final class LoyaltyService {
    private final OrderRepository orders;

    LoyaltyService(OrderRepository orders) { this.orders = orders; }

    int points(String customer) {
        return orders.findByCustomer(customer).stream()
            .mapToInt(o -> o.totalCents() / 100)
            .sum();
    }
}
// ]]

class Main {
    public static void main(String[] args) {
        // [[client
        OrderRepository orders = new InMemoryOrderRepository();
        orders.save(new Order(new OrderId("o-1"), "ada", 2550));
        orders.save(new Order(new OrderId("o-2"), "bob", 900));
        orders.save(new Order(new OrderId("o-3"), "ada", 1000));
        var loyalty = new LoyaltyService(orders);
        System.out.println("ada -> " + loyalty.points("ada"));
        System.out.println("o-2 -> " + orders.findById(new OrderId("o-2")));
        System.out.println("o-9 -> " + orders.findById(new OrderId("o-9")));
        // ]]
    }
}
