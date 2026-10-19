import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

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

    public void save(Order order) {
        rows.put(order.id(), order);
    }

    public void remove(OrderId id) {
        rows.remove(id);
    }
}
