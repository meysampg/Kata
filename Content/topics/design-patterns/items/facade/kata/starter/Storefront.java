// The web layer. It knows far too much about how an order is placed.
final class Storefront {
    private final Inventory inventory = new Inventory();
    private final Payments payments = new Payments();
    private final Shipping shipping = new Shipping();

    // Callers use this. Keep its signature and replies.
    String buy(String sku, int qty, String card, String address) {
        String id = sku.trim().toUpperCase();
        if (!inventory.reserve(id, qty)) {
            return "REJECTED stock";
        }
        if (!payments.charge(card, 1999L * qty)) {
            inventory.release(id, qty);
            return "REJECTED payment";
        }
        return "OK " + shipping.book(id, address);
    }
}
