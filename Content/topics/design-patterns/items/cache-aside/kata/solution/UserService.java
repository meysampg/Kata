import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.function.LongSupplier;

// Reads go through a cache with a TTL; the store is the truth.
// Support wants a rename to show up at once, and a new user too.
final class UserService {
    private record Entry(String name, long expiresAt) { }

    private final UserStore store;
    private final LongSupplier clock;
    private final long ttlMs;
    private final Map<String, Entry> cache = new ConcurrentHashMap<>();

    UserService(UserStore store, LongSupplier clock, long ttlMs) {
        this.store = store;
        this.clock = clock;
        this.ttlMs = ttlMs;
    }

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

    void rename(String id, String name) {
        store.save(id, name);
        cache.remove(id);
    }
}
