import java.util.List;
import java.util.Optional;

final class InMemoryOrderRepository implements OrderRepository {
    public Optional<Order> findById(OrderId id) {
        throw new UnsupportedOperationException("TODO");
    }

    public List<Order> findByCustomer(String customer) {
        throw new UnsupportedOperationException("TODO");
    }

    public void save(Order order) {
        throw new UnsupportedOperationException("TODO");
    }

    public void remove(OrderId id) {
        throw new UnsupportedOperationException("TODO");
    }
}
