final class Storefront {
    private final OrderService orders = new OrderService();

    String buy(String sku, int qty, String card, String address) {
        String id = sku.trim().toUpperCase();
        return switch (orders.place(id, qty, card, address)) {
            case Outcome.Placed p -> "OK " + p.tracking();
            case Outcome.Rejected r -> "REJECTED " + r.reason();
        };
    }
}
