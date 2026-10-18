import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

// [[messages
record PlaceOrder(String orderId, String customer, int cents) {}
record OrderPlaced(String orderId, String customer, int cents) {}
// ]]

// [[write
final class OrderCommands {
    private final Map<String, PlaceOrder> orders = new HashMap<>();
    private final List<OrderPlaced> feed = new ArrayList<>();

    void handle(PlaceOrder cmd) {
        if (cmd.cents() <= 0) throw new IllegalArgumentException("amount");
        if (orders.putIfAbsent(cmd.orderId(), cmd) != null)
            throw new IllegalStateException("duplicate " + cmd.orderId());
        feed.add(new OrderPlaced(cmd.orderId(), cmd.customer(), cmd.cents()));
    }

    List<OrderPlaced> feed() { return List.copyOf(feed); }
}
// ]]

// [[read
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
            .sorted(Map.Entry.<String, Integer>comparingByValue().reversed())
            .limit(n).map(e -> e.getKey() + "=" + e.getValue()).toList();
    }
}
// ]]

class Main {
    public static void main(String[] args) {
        var commands = new OrderCommands();
        var view = new RevenueView();
        // [[client
        commands.handle(new PlaceOrder("o1", "ada", 1500));
        commands.handle(new PlaceOrder("o2", "bob", 700));
        commands.handle(new PlaceOrder("o3", "ada", 1000));
        System.out.println("before: " + view.revenue("ada"));
        view.catchUp(commands.feed());
        System.out.println("after: " + view.revenue("ada"));
        System.out.println(view.top(2));
        // ]]
        try {
            commands.handle(new PlaceOrder("o1", "eve", 100));
        } catch (IllegalStateException e) {
            System.out.println("rejected: " + e.getMessage());
        }
    }
}
