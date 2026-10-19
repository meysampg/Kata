import java.util.Objects;

final class LoyaltyService {
    private final OrderRepository orders;

    LoyaltyService(OrderRepository orders) {
        this.orders = Objects.requireNonNull(orders, "orders");
    }

    int points(String customer) {
        return orders.findByCustomer(customer).stream()
            .mapToInt(o -> o.totalCents() / 100)
            .sum();
    }
}
