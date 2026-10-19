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

    @Check(id = "account-knows-nothing-of-tracking", kind = Kind.DESIGN)
    void accountKnowsNothing() {
        var account = Source.type("Account");
        Expect.none(account.mentions("UnitOfWork"), "Account refers to the unit of work");
        Expect.isTrue(Types.fieldsOfType(Types.named("Account"), Types.named("UnitOfWork")).isEmpty(),
            "Account should not hold a UnitOfWork");
    }
}
