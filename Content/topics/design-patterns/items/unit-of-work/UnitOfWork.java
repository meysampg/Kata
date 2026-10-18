import java.util.LinkedHashMap;
import java.util.Map;
import java.util.TreeMap;

// [[changes
sealed interface Change permits Insert, Update, Delete {}
record Insert(String id, int value) implements Change {}
record Update(String id, int value) implements Change {}
record Delete(String id) implements Change {}
// ]]

final class UnitOfWork {
    private final TreeMap<String, Integer> db;
    private final Map<String, Change> pending = new LinkedHashMap<>();

    UnitOfWork(TreeMap<String, Integer> db) { this.db = db; }

    // [[register
    void registerNew(String id, int value) {
        pending.put(id, new Insert(id, value));
    }

    void registerDirty(String id, int value) {
        pending.merge(id, new Update(id, value), (old, now) ->
            old instanceof Insert ? new Insert(id, value)
            : old instanceof Update ? now : old);
    }

    void registerRemoved(String id) {
        if (pending.get(id) instanceof Insert) pending.remove(id);
        else pending.put(id, new Delete(id));
    }
    // ]]

    // [[commit
    int commit() {
        var copy = new TreeMap<>(db);
        for (Change c : pending.values()) {
            switch (c) {
                case Insert i -> {
                    if (copy.putIfAbsent(i.id(), i.value()) != null)
                        throw new IllegalStateException("duplicate " + i.id());
                }
                case Update u -> {
                    if (copy.replace(u.id(), u.value()) == null)
                        throw new IllegalStateException("missing " + u.id());
                }
                case Delete d -> copy.remove(d.id());
            }
        }
        db.clear();
        db.putAll(copy);
        int applied = pending.size();
        pending.clear();
        return applied;
    }
    // ]]
}

class Main {
    public static void main(String[] args) {
        var db = new TreeMap<>(Map.of("a", 100, "b", 50));
        // [[client
        var work = new UnitOfWork(db);
        work.registerNew("c", 10);
        work.registerDirty("a", 70);
        work.registerDirty("a", 60);
        work.registerRemoved("b");
        System.out.println("committed " + work.commit() + " changes");
        System.out.println(db);
        // ]]
        var bad = new UnitOfWork(db);
        bad.registerDirty("a", 1);
        bad.registerDirty("zzz", 5);
        try {
            bad.commit();
        } catch (IllegalStateException e) {
            System.out.println("rolled back: " + e.getMessage());
        }
        System.out.println(db);
    }
}
