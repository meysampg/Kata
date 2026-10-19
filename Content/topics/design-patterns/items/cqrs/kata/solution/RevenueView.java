import java.util.HashMap;
import java.util.List;
import java.util.Map;

// Read side: a projection built only from the feed.
final class RevenueView {
    private final Map<String, Integer> byCustomer = new HashMap<>();
    private int applied;

    void catchUp(List<OrderPlaced> feed) {
        for (; applied < feed.size(); applied++) {
            var e = feed.get(applied);
            byCustomer.merge(e.customer(), e.cents(), Integer::sum);
        }
    }

    int revenue(String customer) {
        return byCustomer.getOrDefault(customer, 0);
    }

    List<String> top(int n) {
        return byCustomer.entrySet().stream()
            .sorted(Map.Entry.<String, Integer>comparingByValue().reversed()
                .thenComparing(Map.Entry.comparingByKey()))
            .limit(n).map(e -> e.getKey() + "=" + e.getValue()).toList();
    }
}
