import java.io.IOException;

final class Relay {
    private final Db db;
    private final Broker broker;

    Relay(Db db, Broker broker) {
        this.db = db;
        this.broker = broker;
    }

    /** Publishes pending rows oldest first; stops at the first failure. */
    int pump() {
        int sent = 0;
        for (Message row : db.pending()) {
            try {
                broker.publish(row);
            } catch (IOException e) {
                return sent;
            }
            db.markPublished(row.id());
            sent++;
        }
        return sent;
    }
}
