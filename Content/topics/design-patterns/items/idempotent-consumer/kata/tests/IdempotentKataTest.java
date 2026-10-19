import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;
import kata.*;

class IdempotentKataTest {
    static final class Books implements Ledger {
        final Map<String, Long> balances = new TreeMap<>();
        boolean failNext;
        long pauseMs;
        int credits;

        public void credit(String account, long cents) {
            if (pauseMs > 0) Stress.pause(pauseMs);   // widens the race window
            synchronized (this) {
                if (failNext) {
                    failNext = false;
                    throw new IllegalStateException("db down");
                }
                credits++;
                balances.merge(account, cents, Long::sum);
            }
        }
    }

    final Books books = new Books();
    final AccountConsumer consumer = new AccountConsumer(books);

    @Check(id = "first-delivery-applied")
    void firstDeliveryApplied() {
        Expect.isTrue(consumer.handle(new Deposit("m1", "alice", 500)),
            "a first delivery should be applied");
        Expect.equal(Map.of("alice", 500L), books.balances, "balances");
    }

    @Check(id = "duplicate-is-skipped")
    void duplicateIsSkipped() {
        Deposit m1 = new Deposit("m1", "alice", 500);
        consumer.handle(m1);
        Expect.isTrue(!consumer.handle(m1), "a redelivered message should report false");
        Expect.equal(Map.of("alice", 500L), books.balances, "balances after a duplicate");
    }

    @Check(id = "late-duplicate-is-skipped")
    void lateDuplicateIsSkipped() {
        consumer.handle(new Deposit("m1", "alice", 500));
        consumer.handle(new Deposit("m2", "bob", 300));
        consumer.handle(new Deposit("m3", "alice", 250));
        Expect.isTrue(!consumer.handle(new Deposit("m1", "alice", 500)),
            "m1 redelivered after other messages");
        Expect.equal(Map.of("alice", 750L, "bob", 300L), books.balances, "balances");
    }

    @Check(id = "identity-is-the-message-id")
    void identityIsTheMessageId() {
        Expect.isTrue(consumer.handle(new Deposit("m1", "alice", 500)), "m1");
        Expect.isTrue(consumer.handle(new Deposit("m2", "alice", 500)),
            "a different message with identical content is a different deposit");
        Expect.equal(Map.of("alice", 1000L), books.balances, "balances");
    }

    @Check(id = "failed-effect-can-be-redelivered")
    void failedEffectCanBeRedelivered() {
        Deposit m1 = new Deposit("m1", "alice", 500);
        books.failNext = true;
        Expect.raises(IllegalStateException.class, () -> consumer.handle(m1),
            "a delivery whose effect fails");
        Expect.isTrue(consumer.handle(m1),
            "the redelivery after a failure must be applied, not skipped");
        Expect.equal(Map.of("alice", 500L), books.balances, "balances");
    }

    @Check(id = "concurrent-duplicates-apply-once", timeoutMs = 5000)
    void concurrentDuplicatesApplyOnce() {
        books.pauseMs = 30;
        Deposit m1 = new Deposit("m1", "alice", 500);
        List<Boolean> applied = Stress.race(6, () -> consumer.handle(m1));
        long wins = applied.stream().filter(a -> a).count();
        Expect.equal(1L, wins, "deliveries reported as applied");
        Expect.equal(Map.of("alice", 500L), books.balances,
            "balances after the same message arrived on 6 threads at once");
    }

    @Check(id = "concurrent-distinct-messages-all-apply", timeoutMs = 5000)
    void concurrentDistinctMessagesAllApply() {
        java.util.concurrent.atomic.AtomicInteger n =
            new java.util.concurrent.atomic.AtomicInteger();
        List<Boolean> applied = Stress.race(6, () ->
            consumer.handle(new Deposit("m" + n.incrementAndGet(), "alice", 100)));
        Expect.isTrue(applied.stream().allMatch(a -> a),
            "six different messages should all be applied");
        Expect.equal(Map.of("alice", 600L), books.balances, "balances");
    }
}
