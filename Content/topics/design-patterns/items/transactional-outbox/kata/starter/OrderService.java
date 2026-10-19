import java.io.IOException;

// Places orders and tells the world about them: two writes, no shared fate.
final class OrderService {
    private final Db db;
    private final Broker broker;

    OrderService(Db db, Broker broker) {
        this.db = db;
        this.broker = broker;
    }

    boolean place(String id) {
        boolean saved = db.inTransaction(tx -> tx.saveOrder(id));
        if (!saved) {
            return false;
        }
        try {
            broker.publish(new Message(0, "OrderPlaced", id));
        } catch (IOException e) {
            // swallowed: the order exists but nobody hears about it
        }
        return true;
    }
}

// Callers use this entry point. Keep its signature and behaviour.
final class Shop {
    private final OrderService orders;

    Shop(Db db, Broker broker) {
        this.orders = new OrderService(db, broker);
    }

    boolean place(String id) {
        return orders.place(id);
    }

    /** Delivers whatever is waiting to the broker; returns how many. */
    int deliver() {
        return 0;
    }
}
