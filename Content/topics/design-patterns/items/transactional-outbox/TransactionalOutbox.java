import java.io.IOException;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.function.Consumer;

record OutboxRow(long id, String type, String payload) {}
interface Broker { void publish(OutboxRow row) throws IOException; }

// [[database
final class Db {
    record Tx(List<String> orders, List<OutboxRow> rows) {}
    final List<String> orders = new ArrayList<>();
    final List<OutboxRow> outbox = new ArrayList<>();
    private final Set<Long> published = new HashSet<>();
    private long seq;
    void placeOrder(Tx tx, String id) {
        tx.orders().add(id);
        tx.rows().add(new OutboxRow(++seq, "OrderPlaced", id));
    }
    boolean inTransaction(Consumer<Tx> work) {
        var tx = new Tx(new ArrayList<>(), new ArrayList<>());
        try {
            work.accept(tx);
        } catch (RuntimeException e) {
            return false; // rollback: both buffers are dropped
        }
        orders.addAll(tx.orders()); // commit: data and message together
        outbox.addAll(tx.rows());
        return true;
    }
    // ]]

    // [[relay
    int relay(Broker broker) {
        int sent = 0;
        for (OutboxRow row : outbox) {
            if (published.contains(row.id())) continue;
            try {
                broker.publish(row);
            } catch (IOException e) {
                return sent; // keep the row; retry on the next poll
            }
            published.add(row.id()); // mark only after the broker acked
            sent++;
        }
        return sent;
    }
    // ]]
}

class Main {
    public static void main(String[] args) {
        var db = new Db();
        // [[write
        System.out.println(db.inTransaction(tx -> db.placeOrder(tx, "o-1")));
        System.out.println(db.inTransaction(tx -> {
            db.placeOrder(tx, "o-2");
            throw new IllegalStateException("constraint violated");
        }));
        System.out.println(db.orders + " outbox=" + db.outbox.size());
        // ]]
        // [[publish
        int[] calls = {0};
        var seen = new ArrayList<String>();
        Broker flaky = row -> {
            if (calls[0]++ == 0) throw new IOException("broker down");
            seen.add(row.type() + ":" + row.payload());
        };
        for (int poll = 1; poll <= 3; poll++) {
            System.out.println("poll" + poll + " sent=" + db.relay(flaky));
        }
        System.out.println(seen);
        // ]]
    }
}
