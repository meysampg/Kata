import java.io.IOException;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.function.Consumer;

record Message(long id, String type, String payload) { }

interface Broker {
    void publish(Message message) throws IOException;
}

// A tiny database: one transaction commits orders and outbox rows together.
final class Db {
    final class Tx {
        private final List<String> orders = new ArrayList<>();
        private final List<Message> rows = new ArrayList<>();

        void saveOrder(String id) {
            if (Db.this.orders.contains(id) || orders.contains(id)) {
                throw new IllegalStateException("duplicate order " + id);
            }
            orders.add(id);
        }

        void enqueue(String type, String payload) {
            rows.add(new Message(++seq, type, payload));
        }
    }

    final List<String> orders = new ArrayList<>();
    final List<Message> outbox = new ArrayList<>();
    private final Set<Long> published = new HashSet<>();
    private long seq;
    /** How many transactions have committed. */
    int commits;

    /** Commits on return, rolls everything back if work throws. */
    boolean inTransaction(Consumer<Tx> work) {
        Tx tx = new Tx();
        try {
            work.accept(tx);
        } catch (RuntimeException e) {
            return false;
        }
        orders.addAll(tx.orders);
        outbox.addAll(tx.rows);
        commits++;
        return true;
    }

    /** Outbox rows not yet acknowledged by the broker, oldest first. */
    List<Message> pending() {
        return outbox.stream()
            .filter(m -> !published.contains(m.id())).toList();
    }

    void markPublished(long id) {
        published.add(id);
    }
}
