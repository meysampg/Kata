import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

// [[events
sealed interface Event permits Deposited, Withdrawn {}
record Deposited(int cents) implements Event {}
record Withdrawn(int cents) implements Event {}
// ]]

// [[store
final class EventStore {
    private final Map<String, List<Event>> streams = new HashMap<>();
    List<Event> load(String id) {
        return List.copyOf(streams.getOrDefault(id, List.of()));
    }
    void append(String id, int expected, List<Event> events) {
        var s = streams.computeIfAbsent(id, k -> new ArrayList<>());
        if (s.size() != expected)
            throw new IllegalStateException("conflict at v" + s.size());
        s.addAll(events);
    }
}
// ]]

final class Account {
    private final List<Event> fresh = new ArrayList<>();
    private int balance, version;
    // [[replay
    static Account replay(List<Event> history) {
        var account = new Account();
        history.forEach(account::apply);
        return account;
    }
    private void apply(Event e) {
        switch (e) {
            case Deposited d -> balance += d.cents();
            case Withdrawn w -> balance -= w.cents();
        }
        version++;
    }
    // ]]

    // [[commands
    void deposit(int cents) { record(new Deposited(cents)); }
    void withdraw(int cents) {
        if (cents > balance) throw new IllegalStateException("funds");
        record(new Withdrawn(cents));
    }
    private void record(Event e) { apply(e); fresh.add(e); }
    void saveTo(EventStore store, String id) {
        store.append(id, version - fresh.size(), fresh);
        fresh.clear();
    }
    // ]]
    int balance() { return balance; }
    int version() { return version; }
}

class Main {
    public static void main(String[] args) {
        var store = new EventStore();
        // [[client
        var acc = Account.replay(store.load("acc-1"));
        acc.deposit(100);
        acc.withdraw(30);
        acc.saveTo(store, "acc-1");
        System.out.println(acc.balance() + " at v" + acc.version());
        var then = Account.replay(store.load("acc-1").subList(0, 1));
        System.out.println(then.balance() + " at v" + then.version());
        // ]]
        // [[conflict
        var rival = Account.replay(store.load("acc-1"));
        rival.deposit(5);
        rival.saveTo(store, "acc-1");
        acc.deposit(10);
        try { acc.saveTo(store, "acc-1"); }
        catch (IllegalStateException e) { System.out.println(e.getMessage()); }
        // ]]
    }
}
