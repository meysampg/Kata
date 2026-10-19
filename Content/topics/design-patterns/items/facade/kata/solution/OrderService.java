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
