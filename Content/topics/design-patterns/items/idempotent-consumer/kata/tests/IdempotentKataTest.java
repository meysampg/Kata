import java.util.List;
import java.util.Map;
import java.util.TreeMap;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;
import kata.*;

class IdempotentKataTest {
    static final class Books implements Ledger {
        final Map<String, Long> balances = new TreeMap<>();
        final AtomicInteger entered = new AtomicInteger();
        boolean failNext;
        /** Runs inside the first credit call, before it books anything. */
        volatile Runnable duringFirst = () -> { };

        public void credit(String account, long cents) {
            if (entered.incrementAndGet() == 1) duringFirst.run();
            synchronized (this) {
                if (failNext) {
                    failNext = false;
                    throw new IllegalStateException("db down");
                }
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

    @Check(id = "concurrent-duplicates-apply-once")
    void concurrentDuplicatesApplyOnce() throws Exception {
        Deposit m1 = new Deposit("m1", "alice", 500);
        AtomicReference<Thread> second = new AtomicReference<>();
        CountDownLatch firstIn = new CountDownLatch(1);
        // The first delivery stays inside credit until the duplicate has
        // either reached credit too (the bug), returned, or is waiting for it.
        books.duringFirst = () -> {
            firstIn.countDown();
            long deadline = System.nanoTime() + 1_000_000_000L;
            while (System.nanoTime() < deadline && books.entered.get() == 1) {
                Thread b = second.get();
                if (b != null && b.getState() != Thread.State.NEW
                        && b.getState() != Thread.State.RUNNABLE) {
                    return;  // returned, or blocked behind the first delivery
                }
                Thread.onSpinWait();
            }
        };
        AtomicReference<Boolean> first = new AtomicReference<>();
        AtomicReference<Boolean> dup = new AtomicReference<>();
        Thread a = daemon(() -> first.set(consumer.handle(m1)));
        a.start();
        Expect.isTrue(firstIn.await(1, TimeUnit.SECONDS), "the first delivery never "
            + "reached ledger.credit");
        Thread b = daemon(() -> dup.set(consumer.handle(m1)));
        second.set(b);
        b.start();
        a.join(2000);
        b.join(2000);
        Expect.isTrue(!a.isAlive() && !b.isAlive(), "the two deliveries of m1 did not finish");
        long wins = java.util.stream.Stream.of(first.get(), dup.get())
            .filter(Boolean.TRUE::equals).count();
        Expect.equal(1L, wins, "deliveries of m1 reported as applied while a "
            + "duplicate arrived during the first one's credit");
        Expect.equal(Map.of("alice", 500L), books.balances, "balances after m1 "
            + "arrived twice at once (check, apply and mark must be one step)");
    }

    static Thread daemon(Runnable r) {
        Thread t = new Thread(r, "kata-delivery");
        t.setDaemon(true);
        return t;
    }

    @Check(id = "concurrent-distinct-messages-all-apply")
    void concurrentDistinctMessagesAllApply() {
        AtomicInteger n = new AtomicInteger();
        List<Boolean> applied = Stress.race(6, () ->
            consumer.handle(new Deposit("m" + n.incrementAndGet(), "alice", 100)));
        Expect.isTrue(applied.stream().allMatch(a -> a),
            "six different messages should all be applied");
        Expect.equal(Map.of("alice", 600L), books.balances, "balances");
    }
}
