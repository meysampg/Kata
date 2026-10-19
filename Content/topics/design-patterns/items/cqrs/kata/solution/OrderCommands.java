import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

// Write side: validates, keeps current state, announces facts.
final class OrderCommands {
    private final Set<String> placed = new HashSet<>();
    private final List<OrderPlaced> feed = new ArrayList<>();

    void handle(PlaceOrder cmd) {
        if (cmd.cents() <= 0) throw new IllegalArgumentException("amount");
        if (!placed.add(cmd.orderId())) {
            throw new IllegalStateException("duplicate " + cmd.orderId());
        }
        feed.add(new OrderPlaced(cmd.orderId(), cmd.customer(), cmd.cents()));
    }

    List<OrderPlaced> feed() { return List.copyOf(feed); }
}
