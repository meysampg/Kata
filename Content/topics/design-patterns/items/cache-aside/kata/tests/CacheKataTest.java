import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicLong;
import kata.*;

class CacheKataTest {
    static final class FakeStore implements UserStore {
        final Map<String, String> rows = new HashMap<>();
        int reads;
        Runnable beforeSave = () -> { };

        public synchronized Optional<String> find(String id) {
            reads++;
            return Optional.ofNullable(rows.get(id));
        }

        public void save(String id, String name) {
            beforeSave.run();
            synchronized (this) {
                rows.put(id, name);
            }
        }
    }

    final AtomicLong now = new AtomicLong();
    final FakeStore db = new FakeStore();
    final UserService users = new UserService(db, now::get, 60_000);

    @Check(id = "second-read-is-a-hit")
    void secondReadIsAHit() {
        db.rows.put("u1", "Ada");
        Expect.equal(Optional.of("Ada"), users.get("u1"), "first read");
        Expect.equal(Optional.of("Ada"), users.get("u1"), "second read");
        Expect.equal(1, db.reads, "store reads for two gets");
    }

    @Check(id = "rename-is-visible-at-once")
    void renameIsVisibleAtOnce() {
        db.rows.put("u1", "Ada");
        users.get("u1");
        users.rename("u1", "Grace");
        Expect.equal(Optional.of("Grace"), users.get("u1"),
            "a read right after rename (the cache still holds the old name)");
    }

    @Check(id = "rename-writes-before-it-evicts")
    void renameWritesBeforeItEvicts() {
        db.rows.put("u1", "Ada");
        users.get("u1");
        // A reader slips in while the write is in progress and re-fills the cache.
        db.beforeSave = () -> users.get("u1");
        users.rename("u1", "Grace");
        db.beforeSave = () -> { };
        Expect.equal(Optional.of("Grace"), users.get("u1"),
            "a read after rename when a reader raced the write "
                + "(write the store first, then evict)");
    }

    @Check(id = "missing-rows-are-not-cached")
    void missingRowsAreNotCached() {
        Expect.equal(Optional.empty(), users.get("u9"), "a user that does not exist yet");
        db.rows.put("u9", "Lin");
        Expect.equal(Optional.of("Lin"), users.get("u9"),
            "the same user after it was created (do not cache absence)");
    }

    @Check(id = "ttl-bounds-staleness")
    void ttlBoundsStaleness() {
        db.rows.put("u1", "Ada");
        users.get("u1");
        db.rows.put("u1", "Grace");          // changed behind the cache's back
        now.set(59_999);
        Expect.equal(Optional.of("Ada"), users.get("u1"), "a read before the TTL ends");
        now.set(60_000);
        Expect.equal(Optional.of("Grace"), users.get("u1"), "a read once the TTL ended");
        Expect.equal(2, db.reads, "store reads");
    }

    @Check(id = "rename-evicts-only-that-user")
    void renameEvictsOnlyThatUser() {
        db.rows.put("u1", "Ada");
        db.rows.put("u2", "Bob");
        users.get("u1");
        users.get("u2");
        users.rename("u1", "Grace");
        int before = db.reads;
        users.get("u2");
        Expect.equal(before, db.reads, "reading u2 after renaming u1 should still be a hit");
    }

    @Check(id = "concurrent-readers-agree", timeoutMs = 4000)
    void concurrentReadersAgree() {
        db.rows.put("u1", "Ada");
        List<Optional<String>> all = Stress.race(8, () -> users.get("u1"));
        for (Optional<String> r : all) {
            Expect.equal(Optional.of("Ada"), r, "a concurrent read");
        }
    }
}
