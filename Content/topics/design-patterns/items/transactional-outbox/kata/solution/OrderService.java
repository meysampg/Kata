final class OrderService {
    private final Db db;

    OrderService(Db db) {
        this.db = db;
    }

    boolean place(String id) {
        return db.inTransaction(tx -> {
            tx.saveOrder(id);
            tx.enqueue("OrderPlaced", id);
        });
    }
}
