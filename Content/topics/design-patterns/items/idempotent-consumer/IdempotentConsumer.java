import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.TreeMap;
import java.util.Map;

// [[message
record Deposit(String messageId, String account, long cents) { }
// ]]

final class AccountConsumer {
    private final Set<String> processed = new HashSet<>();
    private final Map<String, Long> balances = new TreeMap<>();

    // [[handle
    /** With a database: check, effect and mark in one transaction. */
    synchronized boolean handle(Deposit m) {
        if (processed.contains(m.messageId())) {
            return false;
        }
        balances.merge(m.account(), m.cents(), Long::sum);
        processed.add(m.messageId());
        return true;
    }
    // ]]

    Map<String, Long> balances() { return balances; }
}

class Main {
    public static void main(String[] args) {
        var consumer = new AccountConsumer();
        // [[deliveries
        List<Deposit> broker = List.of(
            new Deposit("m1", "alice", 500),
            new Deposit("m2", "bob", 300),
            new Deposit("m1", "alice", 500),   // redelivery after a lost ack
            new Deposit("m3", "alice", 250),
            new Deposit("m2", "bob", 300));    // duplicate publish
        // ]]
        for (Deposit d : broker) {
            boolean applied = consumer.handle(d);
            String verdict = applied ? " applied" : " duplicate";
            System.out.println(d.messageId() + verdict);
        }
        System.out.println(consumer.balances());
    }
}
