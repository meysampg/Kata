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
    boolean charge(String card, long cents) {
        return !card.startsWith("0000");
    }
}

final class Shipping {
    private int booked;

    String book(String sku, String address) {
        booked++;
        return "TRK-" + sku + "-" + booked;
    }
}

sealed interface Outcome {
    record Placed(String tracking) implements Outcome { }

    record Rejected(String reason) implements Outcome { }
}
