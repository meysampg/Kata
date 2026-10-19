import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import java.util.concurrent.atomic.AtomicInteger;
import kata.*;

class TimeoutKataTest {
    static ExecutorService daemonPool() {
        return Executors.newCachedThreadPool(r -> {
            Thread t = new Thread(r, "kata-worker");
            t.setDaemon(true);
            return t;
        });
    }

    /** Blocks until interrupted; records the interruption. */
    static final class Hang implements Remote {
        final CountDownLatch started = new CountDownLatch(1);
        final CountDownLatch interrupted = new CountDownLatch(1);
        final CountDownLatch never = new CountDownLatch(1);

        public String call() throws Exception {
            started.countDown();
            try {
                never.await();
            } catch (InterruptedException e) {
                interrupted.countDown();
                throw e;
            }
            return "late";
        }
    }

    @Check(id = "fast-call-returns", timeoutMs = 3000)
    void fastCallReturns() throws Exception {
        Gateway gateway = new Gateway(daemonPool());
        Expect.equal("42.00", gateway.fetch(() -> "42.00", 1000), "a fast call");
    }

    @Check(id = "slow-call-times-out", timeoutMs = 4000)
    void slowCallTimesOut() {
        Gateway gateway = new Gateway(daemonPool());
        Hang hang = new Hang();
        Expect.completesWithin(1500, () -> {
            Expect.raises(TimeoutException.class,
                () -> gateway.fetch(hang, 30), "a call that never returns");
            return null;
        }, "Gateway.fetch with a 30 ms timeout");
    }

    @Check(id = "timeout-cancels-worker", timeoutMs = 4000)
    void timeoutCancelsWorker() throws Exception {
        Gateway gateway = new Gateway(daemonPool());
        Hang hang = new Hang();
        Expect.completesWithin(1500, () -> {
            Expect.raises(TimeoutException.class,
                () -> gateway.fetch(hang, 30), "a call that never returns");
            return null;
        }, "Gateway.fetch with a 30 ms timeout");
        Expect.isTrue(hang.interrupted.await(1500, TimeUnit.MILLISECONDS),
            "After the timeout the abandoned call should be cancelled "
                + "(interrupted), not left running");
    }

    @Check(id = "remote-failure-propagates", timeoutMs = 3000)
    void remoteFailurePropagates() {
        Gateway gateway = new Gateway(daemonPool());
        ExecutionException e = Expect.raises(ExecutionException.class,
            () -> gateway.fetch(() -> {
                throw new IllegalStateException("boom");
            }, 1000), "a remote that throws");
        Expect.isTrue(e.getCause() instanceof IllegalStateException,
            "ExecutionException should carry the remote's own exception");
    }

    @Check(id = "caller-interrupt-cancels", timeoutMs = 4000)
    void callerInterruptCancels() throws Exception {
        Gateway gateway = new Gateway(daemonPool());
        Hang hang = new Hang();
        AtomicInteger outcome = new AtomicInteger();
        Thread caller = new Thread(() -> {
            try {
                gateway.fetch(hang, 10_000);
            } catch (InterruptedException e) {
                outcome.set(1);
            } catch (Exception e) {
                outcome.set(2);
            }
        }, "kata-caller");
        caller.setDaemon(true);
        caller.start();
        Expect.isTrue(hang.started.await(1500, TimeUnit.MILLISECONDS),
            "the remote call never started");
        caller.interrupt();
        caller.join(1500);
        Expect.equal(1, outcome.get(),
            "an interrupted caller should get InterruptedException");
        Expect.isTrue(hang.interrupted.await(1500, TimeUnit.MILLISECONDS),
            "Interrupting the caller should cancel the remote call too");
    }

    @Check(id = "no-unbounded-wait", kind = Kind.DESIGN)
    void noUnboundedWait() {
        var fetch = Source.type("Gateway").method("fetch");
        boolean bounded = !fetch.mentions("TimeUnit").isEmpty()
            || !fetch.mentions("Duration").isEmpty()
            || !fetch.calls("orTimeout").isEmpty();
        Expect.isTrue(bounded,
            "Gateway.fetch does not pass timeoutMs to a timed wait "
                + "(use the Future.get overload that takes a unit)");
        Expect.none(fetch.calls("join"),
            "Gateway.fetch must not join without a bound");
    }

    @Check(id = "cancel-on-timeout", kind = Kind.DESIGN)
    void cancelOnTimeout() {
        var fetch = Source.type("Gateway").method("fetch");
        Expect.isTrue(!fetch.calls("cancel").isEmpty(),
            "Gateway.fetch never cancels the abandoned work");
    }
}
