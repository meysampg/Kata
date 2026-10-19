import java.util.List;
import java.util.Optional;

// The port. The domain talks to this, never to a concrete store.
interface OrderRepository {
    Optional<Order> findById(OrderId id);
    List<Order> findByCustomer(String customer);
    void save(Order order);
    void remove(OrderId id);
}
