import java.util.HashMap;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;
import java.util.function.LongSupplier;

interface UserStore {
    Optional<String> find(String id);
    void save(String id, String name);
}

// [[source
final class CountingStore implements UserStore {
    private final Map<String, String> rows = new HashMap<>();
    int reads;

    public Optional<String> find(String id) {
        reads++;
        return Optional.ofNullable(rows.get(id));
    }
    public void save(String id, String name) { rows.put(id, name); }
}
// ]]

final class UserService {
    private record Entry(String name, long expiresAt) { }

    private final UserStore store;
    private final LongSupplier clock;
    private final long ttlMs;
    private final Map<String, Entry> cache = new ConcurrentHashMap<>();

    UserService(UserStore store, LongSupplier clock, long ttlMs) {
        this.store = store; this.clock = clock; this.ttlMs = ttlMs;
    }

    // [[read
    Optional<String> get(String id) {
        Entry hit = cache.get(id);
        if (hit != null && hit.expiresAt() > clock.getAsLong()) {
            return Optional.of(hit.name());
        }
        Optional<String> row = store.find(id);
        long expiresAt = clock.getAsLong() + ttlMs;
        row.ifPresent(n -> cache.put(id, new Entry(n, expiresAt)));
        return row;
    }
    // ]]

    // [[write
    void rename(String id, String name) {
        store.save(id, name);
        cache.remove(id);
    }
    // ]]
}

class Main {
    public static void main(String[] args) {
        var now = new AtomicLong();
        var db = new CountingStore();
        db.save("u1", "Ada");
        var users = new UserService(db, now::get, 60_000);
        System.out.println(users.get("u1").get() + " reads=" + db.reads);
        System.out.println(users.get("u1").get() + " reads=" + db.reads);
        users.rename("u1", "Grace");
        System.out.println(users.get("u1").get() + " reads=" + db.reads);
        now.set(61_000);
        System.out.println(users.get("u1").get() + " reads=" + db.reads);
        System.out.println(users.get("zz").isPresent() + " reads=" + db.reads);
    }
}
