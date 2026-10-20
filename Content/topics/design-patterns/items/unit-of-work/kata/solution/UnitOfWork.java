import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

final class UnitOfWork {
    private final Map<String, Integer> db;
    private final Map<String, Account> loaded = new LinkedHashMap<>();
    private final Map<String, Integer> snapshot = new LinkedHashMap<>();
    private final List<Account> created = new ArrayList<>();
    private final List<Account> removed = new ArrayList<>();

    UnitOfWork(Map<String, Integer> db) {
        this.db = db;
    }

    Account load(String id) {
        Account known = loaded.get(id);
        if (known != null) return known;
        Integer stored = db.get(id);
        if (stored == null) {
            throw new IllegalArgumentException("unknown account: " + id);
        }
        Account account = new Account(id, stored);
        loaded.put(id, account);
        snapshot.put(id, stored);
        return account;
    }

    void registerNew(Account account) {
        created.add(account);
    }

    void registerRemoved(Account account) {
        removed.add(account);
    }

    List<String> commit() {
        var log = new ArrayList<String>();
        for (Account a : created) {
            db.put(a.id, a.balance);
            log.add("INSERT " + a.id);
        }
        for (Account a : loaded.values()) {
            if (removed.contains(a)) continue;
            if (a.balance == snapshot.get(a.id)) continue;
            db.put(a.id, a.balance);
            log.add("UPDATE " + a.id);
        }
        for (Account a : removed) {
            db.remove(a.id);
            log.add("DELETE " + a.id);
        }
        // Start clean: forget the removed, track the inserted, re-snapshot.
        for (Account a : removed) {
            loaded.remove(a.id);
            snapshot.remove(a.id);
        }
        for (Account a : created) {
            loaded.put(a.id, a);
        }
        loaded.values().forEach(a -> snapshot.put(a.id, a.balance));
        created.clear();
        removed.clear();
        return log;
    }

    void rollback() {
        loaded.values().forEach(a -> a.balance = snapshot.get(a.id));
        created.clear();
        removed.clear();
    }
}
