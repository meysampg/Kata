final class Shop {
    private final OrderService orders;
    private final Relay relay;

    Shop(Db db, Broker broker) {
        this.orders = new OrderService(db);
        this.relay = new Relay(db, broker);
    }

    boolean place(String id) {
        return orders.place(id);
    }

    int deliver() {
        return relay.pump();
    }
}
