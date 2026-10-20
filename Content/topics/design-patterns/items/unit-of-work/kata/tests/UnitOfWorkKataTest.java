import java.util.List;
import java.util.Map;
import java.util.TreeMap;
import kata.*;

class UnitOfWorkKataTest {
    static TreeMap<String, Integer> db() {
        return new TreeMap<>(Map.of("a", 100, "b", 50, "c", 7));
    }

    @Check(id = "identity-map")
    void identityMap() {
        var work = new UnitOfWork(db());
        Account first = work.load("a");
        Expect.isTrue(first == work.load("a"), "loading the same id twice gives the same object");
        Expect.equal(100, first.balance, "loaded balance");
        Expect.isTrue(first != work.load("b"), "different ids are different objects");
    }

    @Check(id = "unknown-id")
    void unknownId() {
        var work = new UnitOfWork(db());
        Expect.raises(IllegalArgumentException.class, () -> work.load("zzz"),
            "loading an id that is not in the database");
    }

    @Check(id = "nothing-before-commit")
    void nothingBeforeCommit() {
        var db = db();
        var work = new UnitOfWork(db);
        work.load("a").balance = 1;
        work.registerNew(new Account("d", 5));
        work.registerRemoved(work.load("c"));
        Expect.equal(db(), db, "the database before commit");
    }

    @Check(id = "commit-writes-changes")
    void commitWritesChanges() {
        var db = db();
        var work = new UnitOfWork(db);
        work.load("a").balance -= 30;
        work.load("b");
        work.registerNew(new Account("d", 5));
        work.registerRemoved(work.load("c"));
        Expect.equal(List.of("INSERT d", "UPDATE a", "DELETE c"), work.commit(), "commit log");
        Expect.equal(Map.of("a", 70, "b", 50, "d", 5), db, "the database after commit");
    }

    @Check(id = "commit-order")
    void commitOrder() {
        var work = new UnitOfWork(db());
        work.registerRemoved(work.load("c"));
        work.load("b").balance = 51;
        work.load("a").balance = 99;
        work.registerNew(new Account("x", 1));
        work.registerNew(new Account("y", 2));
        Expect.equal(List.of("INSERT x", "INSERT y", "UPDATE b", "UPDATE a", "DELETE c"),
            work.commit(), "inserts, then updates (in load order), then deletes");
    }

    @Check(id = "clean-objects-not-written")
    void cleanObjectsNotWritten() {
        var work = new UnitOfWork(db());
        work.load("a");
        Account b = work.load("b");
        b.balance += 5;
        b.balance -= 5;
        Expect.equal(List.of(), work.commit(), "loaded but unchanged objects");
    }

    @Check(id = "removed-dirty-only-deleted")
    void removedDirtyOnlyDeleted() {
        var db = db();
        var work = new UnitOfWork(db);
        Account c = work.load("c");
        c.balance = 0;
        work.registerRemoved(c);
        Expect.equal(List.of("DELETE c"), work.commit(), "a changed object that is also removed");
        Expect.isTrue(!db.containsKey("c"), "c should be gone");
    }

    @Check(id = "commit-resets-tracking")
    void commitResetsTracking() {
        var db = db();
        var work = new UnitOfWork(db);
        Account a = work.load("a");
        a.balance = 1;
        work.registerNew(new Account("d", 5));
        work.commit();
        Expect.equal(List.of(), work.commit(), "a second commit with no changes");
        a.balance = 2;
        work.load("d").balance = 6;
        Expect.equal(List.of("UPDATE a", "UPDATE d"), work.commit(), "changes after a commit");
        Expect.equal(Map.of("a", 2, "b", 50, "c", 7, "d", 6), db, "the database at the end");
    }

    @Check(id = "rollback")
    void rollback() {
        var db = db();
        var work = new UnitOfWork(db);
        Account a = work.load("a");
        a.balance = 1;
        work.registerNew(new Account("d", 5));
        work.registerRemoved(work.load("c"));
        work.rollback();
        Expect.equal(100, a.balance, "a loaded object after rollback");
        Expect.equal(List.of(), work.commit(), "commit after rollback");
        Expect.equal(db(), db, "the database after rollback");
    }

    /** A database that records which keys were written, and when. */
    static final class SpyDb extends TreeMap<String, Integer> {
        final java.util.Set<String> touched = new java.util.TreeSet<>();
        boolean recording;

        SpyDb() {
            super(Map.of("a", 100, "b", 50, "c", 7));
            recording = true;
        }

        private void touch(Object key) {
            if (recording) touched.add(String.valueOf(key));
        }

        @Override public Integer put(String k, Integer v) { touch(k); return super.put(k, v); }
        @Override public Integer remove(Object k) { touch(k); return super.remove(k); }
        @Override public void putAll(Map<? extends String, ? extends Integer> m) {
            m.keySet().forEach(this::touch);
            super.putAll(m);
        }
        @Override public void clear() { keySet().forEach(this::touch); super.clear(); }
        @Override public Integer putIfAbsent(String k, Integer v) { touch(k); return super.putIfAbsent(k, v); }
        @Override public Integer replace(String k, Integer v) { touch(k); return super.replace(k, v); }
        @Override public Integer merge(String k, Integer v,
                java.util.function.BiFunction<? super Integer, ? super Integer, ? extends Integer> f) {
            touch(k);
            return super.merge(k, v, f);
        }
        @Override public Integer compute(String k,
                java.util.function.BiFunction<? super String, ? super Integer, ? extends Integer> f) {
            touch(k);
            return super.compute(k, f);
        }
    }

    @Check(id = "commit-writes-only-changes")
    void commitWritesOnlyChanges() {
        var db = new SpyDb();
        var work = new UnitOfWork(db);
        work.load("a").balance -= 30;
        work.load("b");
        work.registerNew(new Account("d", 5));
        work.registerRemoved(work.load("c"));
        Expect.equal(java.util.Set.of(), db.touched, "rows written before commit");
        work.commit();
        Expect.equal(new java.util.TreeSet<>(List.of("a", "c", "d")), db.touched,
            "rows commit wrote (only the rows in its log; b did not change)");
    }

    @Check(id = "dirty-check-uses-snapshot", kind = Kind.DESIGN)
    void dirtyCheckUsesSnapshot() {
        var db = db();
        var work = new UnitOfWork(db);
        Account a = work.load("a");
        Account b = work.load("b");
        db.put("a", 999);          // another writer changes the row after we loaded it
        b.balance = 51;
        Expect.equal(List.of("UPDATE b"), work.commit(),
            "commit after another writer changed a; UnitOfWork should compare each account with"
            + " the snapshot it took at load, not with the database");
        Expect.equal(100, a.balance, "the loaded a, which we never changed");
    }
}
