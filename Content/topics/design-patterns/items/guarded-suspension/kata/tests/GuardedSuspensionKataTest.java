import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicInteger;
import kata.*;

class GuardedSuspensionKataTest {
    interface Body<V> {
        V run() throws Exception;
    }

    /** A thread that records what its body returned or threw. */
    static final class Call<V> extends Thread {
        private final Body<V> body;
        volatile V value;
        volatile Throwable error;

        Call(Body<V> body) {
            super(null, null, "kata-call", 0);
            this.body = body;
            setDaemon(true);
        }

        @Override
        public void run() {
            try {
                value = body.run();
            } catch (Throwable t) {
                error = t;
            }
        }
    }

    static <V> Call<V> start(Body<V> body) {
        Call<V> call = new Call<>(body);
        call.start();
        return call;
    }

    /** Waits until the thread is parked; fails if it finished instead of waiting. */
    static void awaitBlocked(Call<?> call, String what) {
        long end = System.nanoTime() + 2_000_000_000L;
        while (System.nanoTime() < end) {
            Thread.State state = call.getState();
            if (state == Thread.State.WAITING || state == Thread.State.TIMED_WAITING
                    || state == Thread.State.BLOCKED) {
                return;
            }
            if (state == Thread.State.TERMINATED) {
                Expect.fail(what + " should wait, but it returned or threw " + call.error);
            }
            Thread.yield();
        }
        Expect.fail(what + " never blocked; is it spinning?");
    }

    static <V> V finish(Call<V> call, String what) throws Exception {
        call.join(3000);
        Expect.isTrue(!call.isAlive(), what + " did not finish");
        if (call.error != null) {
            Expect.fail(what + " threw " + call.error);
        }
        return call.value;
    }

    static void spuriousWakeup(Object monitor) {
        synchronized (monitor) {
            monitor.notifyAll();
        }
    }

    @Check(id = "take-waits-for-put", timeoutMs = 5000)
    void takeWaitsForPut() throws Exception {
        Slot<String> slot = new Slot<>();
        Call<String> taker = start(slot::take);
        awaitBlocked(taker, "take() on an empty slot");
        slot.put("m1");
        Expect.equal("m1", finish(taker, "take()"), "the item taken");
    }

    @Check(id = "put-waits-while-full", timeoutMs = 5000)
    void putWaitsWhileFull() throws Exception {
        Slot<String> slot = new Slot<>();
        slot.put("a");
        Call<String> putter = start(() -> {
            slot.put("b");
            return "done";
        });
        awaitBlocked(putter, "put() on a full slot");
        Expect.equal("a", slot.take(), "the first item, not overwritten");
        finish(putter, "put()");
        Expect.equal("b", slot.take(), "the second item");
    }

    @Check(id = "fifo-handoff", timeoutMs = 5000)
    void fifoHandoff() throws Exception {
        Slot<Integer> slot = new Slot<>();
        Call<String> producer = start(() -> {
            for (int i = 0; i < 50; i++) {
                slot.put(i);
            }
            return "done";
        });
        List<Integer> got = new ArrayList<>();
        for (int i = 0; i < 50; i++) {
            got.add(slot.take());
        }
        finish(producer, "the producer");
        List<Integer> expected = new ArrayList<>();
        for (int i = 0; i < 50; i++) {
            expected.add(i);
        }
        Expect.equal(expected, got, "items in the order they were put");
    }

    @Check(id = "producers-and-consumers", timeoutMs = 5000, repeat = 5)
    void producersAndConsumers() {
        Slot<Integer> slot = new Slot<>();
        AtomicInteger index = new AtomicInteger();
        List<Integer> sums = Stress.race(6, () -> {
            int k = index.getAndIncrement();
            int sum = 0;
            for (int j = 0; j < 20; j++) {
                if (k < 3) {
                    slot.put(k * 100 + j);
                } else {
                    sum += slot.take();
                }
            }
            return sum;
        });
        int total = 0;
        for (int s : sums) {
            total += s;
        }
        Expect.equal(6570, total, "sum of everything consumed");
    }

    @Check(id = "timed-take", timeoutMs = 5000)
    void timedTake() throws Exception {
        Slot<String> slot = new Slot<>();
        Optional<String> none = Expect.completesWithin(2000, () -> slot.take(30), "take(30) on an empty slot");
        Expect.equal(Optional.empty(), none, "take(30) on an empty slot");
        slot.put("m1");
        Expect.equal(Optional.of("m1"), slot.take(30), "take(30) when an item is there");
        Expect.equal(Optional.empty(), slot.take(10), "the slot should be empty after a take");
    }

    @Check(id = "timed-take-wakes-on-put", timeoutMs = 5000)
    void timedTakeWakesOnPut() throws Exception {
        Slot<String> slot = new Slot<>();
        Call<Optional<String>> taker = start(() -> slot.take(4000));
        awaitBlocked(taker, "take(4000) on an empty slot");
        slot.put("m1");
        Expect.equal(Optional.of("m1"), finish(taker, "take(4000)"), "the item taken");
    }

    @Check(id = "interrupt-wakes-taker", timeoutMs = 5000)
    void interruptWakesTaker() throws Exception {
        Slot<String> slot = new Slot<>();
        Call<String> taker = start(slot::take);
        awaitBlocked(taker, "take() on an empty slot");
        taker.interrupt();
        taker.join(3000);
        Expect.isTrue(!taker.isAlive(), "an interrupted take() should stop waiting");
        Expect.isTrue(taker.error instanceof InterruptedException,
            "an interrupted take() should throw InterruptedException but got " + taker.error);
        slot.put("m1");
        Expect.equal("m1", slot.take(), "the slot after an interrupted taker");
    }

    @Check(id = "wakeup-without-change-is-ignored", timeoutMs = 5000)
    void wakeupWithoutChangeIsIgnored() throws Exception {
        Slot<String> slot = new Slot<>();
        Call<String> taker = start(slot::take);
        awaitBlocked(taker, "take() on an empty slot");
        spuriousWakeup(slot);
        taker.join(100);
        Expect.isTrue(taker.isAlive(),
            "take() returned after a wakeup although the slot is empty; recheck the guard in a while loop");
        slot.put("m1");
        Expect.equal("m1", finish(taker, "take()"), "the item taken");

        slot.put("a");
        Call<String> putter = start(() -> {
            slot.put("b");
            return "done";
        });
        awaitBlocked(putter, "put() on a full slot");
        spuriousWakeup(slot);
        putter.join(100);
        Expect.isTrue(putter.isAlive(),
            "put() went ahead after a wakeup although the slot is full; recheck the guard in a while loop");
        Expect.equal("a", slot.take(), "the first item, not overwritten");
        finish(putter, "put()");
    }

    @Check(id = "timed-take-keeps-waiting", timeoutMs = 5000)
    void timedTakeKeepsWaiting() throws Exception {
        Slot<String> slot = new Slot<>();
        Call<Long> taker = start(() -> {
            long t0 = System.nanoTime();
            Optional<String> r = slot.take(300);
            if (r.isPresent()) {
                throw new IllegalStateException("got " + r.get());
            }
            return (System.nanoTime() - t0) / 1_000_000;
        });
        awaitBlocked(taker, "take(300) on an empty slot");
        spuriousWakeup(slot);
        long elapsed = finish(taker, "take(300)");
        Expect.isTrue(elapsed >= 250,
            "take(300) gave up after " + elapsed + " ms because of a wakeup; keep waiting for the remaining time");
    }

    @Check(id = "no-polling", kind = Kind.DESIGN)
    void noPolling() {
        var slot = Source.type("Slot");
        Expect.none(slot.calls("sleep"), "Slot polls with sleep; wait for a signal instead");
        Expect.none(slot.calls("yield"), "Slot spins with yield; wait for a signal instead");
        Expect.none(slot.calls("onSpinWait"), "Slot spins; wait for a signal instead");
    }

    @Check(id = "no-single-notify", kind = Kind.DESIGN)
    void noSingleNotify() {
        Expect.none(Source.type("Slot").calls("notify"),
            "notify() can wake the wrong kind of waiter (a producer instead of a consumer); wake them all or use two Conditions");
    }
}
