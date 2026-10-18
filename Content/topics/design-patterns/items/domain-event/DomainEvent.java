import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Consumer;

// [[events
sealed interface DomainEvent permits OrderPlaced, OrderShipped {}
record OrderPlaced(String orderId, int totalCents) implements DomainEvent {}
record OrderShipped(String orderId) implements DomainEvent {}
// ]]

// [[aggregate
final class Order {
    private final String id;
    private final List<DomainEvent> events = new ArrayList<>();
    private boolean shipped;

    private Order(String id) { this.id = id; }

    static Order place(String id, int totalCents) {
        var order = new Order(id);
        order.events.add(new OrderPlaced(id, totalCents));
        return order;
    }

    void ship() {
        if (shipped) throw new IllegalStateException("already shipped");
        shipped = true;
        events.add(new OrderShipped(id));
    }

    List<DomainEvent> pullEvents() {
        var out = List.copyOf(events);
        events.clear();
        return out;
    }
}
// ]]

// [[bus
final class EventBus {
    private final Map<Class<?>, List<Consumer<DomainEvent>>> handlers =
        new HashMap<>();

    <E extends DomainEvent> void on(Class<E> type, Consumer<E> handler) {
        handlers.computeIfAbsent(type, t -> new ArrayList<>())
            .add(e -> handler.accept(type.cast(e)));
    }

    void publish(List<DomainEvent> events) {
        for (var e : events)
            handlers.getOrDefault(e.getClass(), List.of())
                .forEach(h -> h.accept(e));
    }
}
// ]]

class Main {
    static void say(String s) { System.out.println(s); }

    public static void main(String[] args) {
        var bus = new EventBus();
        bus.on(OrderPlaced.class, e -> say("mail: confirm " + e.orderId()));
        bus.on(OrderPlaced.class, e -> say("ledger: book " + e.totalCents()));
        bus.on(OrderShipped.class, e -> say("mail: shipped " + e.orderId()));

        // [[client
        var order = Order.place("o-1", 4200);
        order.ship();
        System.out.println("saved o-1");
        bus.publish(order.pullEvents());
        // ]]
    }
}
