// [[subsystem
final class Inventory {
    private int stock = 3;

    boolean reserve(String sku, int qty) {
        if (qty > stock) return false;
        stock -= qty;
        return true;
    }

    void release(String sku, int qty) { stock += qty; }
}

final class Payments {
    boolean charge(String card, long cents) { return !card.startsWith("0000"); }
}

final class Shipping {
    String book(String sku, String address) { return "TRK-" + sku + "-1"; }
}
// ]]

// [[result
sealed interface Outcome {
    record Placed(String tracking) implements Outcome {}
    record Rejected(String reason) implements Outcome {}
}
// ]]

// [[facade
final class OrderService {
    private final Inventory inventory = new Inventory();
    private final Payments payments = new Payments();
    private final Shipping shipping = new Shipping();

    Outcome place(String sku, int qty, String card, String address) {
        if (!inventory.reserve(sku, qty)) return new Outcome.Rejected("stock");
        if (!payments.charge(card, 1999L * qty)) {
            inventory.release(sku, qty);
            return new Outcome.Rejected("payment");
        }
        return new Outcome.Placed(shipping.book(sku, address));
    }
}
// ]]

class Main {
    public static void main(String[] args) {
        // [[client
        var orders = new OrderService();
        System.out.println(orders.place("A1", 2, "4111", "Main St 1"));
        System.out.println(orders.place("A1", 2, "4111", "Main St 1"));
        System.out.println(orders.place("A1", 1, "0000", "Main St 1"));
        // ]]
    }
}
