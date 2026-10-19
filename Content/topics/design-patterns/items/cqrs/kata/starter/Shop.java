import java.util.HashMap;
import java.util.Map;

// Writes and reads share one model: every query rescans the orders.
final class Shop {
    private record Order(String customer, int cents) { }

    private final Map<String, Order> orders = new HashMap<>();

    void place(String orderId, String customer, int cents) {
        if (cents <= 0) throw new IllegalArgumentException("amount");
        if (orders.containsKey(orderId)) {
            throw new IllegalStateException("duplicate " + orderId);
        }
        orders.put(orderId, new Order(customer, cents));
    }

    int revenue(String customer) {
        return orders.values().stream()
            .filter(o -> o.customer().equals(customer))
            .mapToInt(Order::cents).sum();
    }

    java.util.List<String> top(int n) {
        var totals = new HashMap<String, Integer>();
        orders.values().forEach(o ->
            totals.merge(o.customer(), o.cents(), Integer::sum));
        return totals.entrySet().stream()
            .sorted(Map.Entry.<String, Integer>comparingByValue().reversed()
                .thenComparing(Map.Entry.comparingByKey()))
            .limit(n).map(e -> e.getKey() + "=" + e.getValue()).toList();
    }
}
