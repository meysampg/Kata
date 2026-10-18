import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;

final class Account {
    final String id;
    int balance;

    Account(String id, int balance) { this.id = id; this.balance = balance; }
}

final class UnitOfWork {
    private final Map<String, Integer> db;
    private final Map<String, Account> loaded = new LinkedHashMap<>();
    private final Map<String, Integer> snapshot = new LinkedHashMap<>();
    private final List<Account> created = new ArrayList<>();
    private final List<String> removed = new ArrayList<>();

    UnitOfWork(Map<String, Integer> db) { this.db = db; }

    // [[identity
    Account load(String id) {
        return loaded.computeIfAbsent(id, k -> {
            snapshot.put(k, db.get(k));
            return new Account(k, db.get(k));
        });
    }
    // ]]

    // [[register
    void registerNew(Account a) { created.add(a); }
    void registerRemoved(Account a) { removed.add(a.id); }
    // ]]

    // [[commit
    List<String> commit() {
        var log = new ArrayList<String>();
        var next = new TreeMap<>(db);
        for (Account a : created) {
            next.put(a.id, a.balance);
            log.add("INSERT " + a.id);
        }
        for (Account a : loaded.values()) {
            boolean same = a.balance == snapshot.get(a.id);
            if (same || removed.contains(a.id)) continue;
            next.put(a.id, a.balance);
            log.add("UPDATE " + a.id);
        }
        for (String id : removed) {
            next.remove(id);
            log.add("DELETE " + id);
        }
        db.clear();
        db.putAll(next);
        return log;
    }
    // ]]
}

class Main {
    public static void main(String[] args) {
        var db = new TreeMap<>(Map.of("a", 100, "b", 50, "c", 7));
        // [[client
        var work = new UnitOfWork(db);
        Account a = work.load("a");
        a.balance -= 30;
        work.load("a").balance -= 10;
        System.out.println("same object: " + (a == work.load("a")));
        work.load("b");
        work.registerNew(new Account("d", 5));
        work.registerRemoved(work.load("c"));
        System.out.println(work.commit());
        System.out.println(db);
        // ]]
    }
}
