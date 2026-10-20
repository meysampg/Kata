import java.util.ArrayList;
import java.util.List;
import java.util.stream.Stream;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import java.util.concurrent.atomic.AtomicInteger;
import kata.*;

class TimeoutKataTest {
    /** Generous for a 30 ms timeout, short enough that a hanging starter fails fast. */
    static final long WAIT_MS = 700;

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

    @Check(id = "fast-call-returns")
    void fastCallReturns() throws Exception {
        Gateway gateway = new Gateway(daemonPool());
        Expect.equal("42.00", gateway.fetch(() -> "42.00", 1000), "a fast call");
    }

    @Check(id = "slow-call-times-out")
    void slowCallTimesOut() {
        Gateway gateway = new Gateway(daemonPool());
        Hang hang = new Hang();
        Expect.completesWithin(WAIT_MS, () -> {
            Expect.raises(TimeoutException.class,
                () -> gateway.fetch(hang, 30), "a call that never returns");
            return null;
        }, "Gateway.fetch with a 30 ms timeout");
    }

    @Check(id = "timeout-cancels-worker")
    void timeoutCancelsWorker() throws Exception {
        Gateway gateway = new Gateway(daemonPool());
        Hang hang = new Hang();
        Expect.completesWithin(WAIT_MS, () -> {
            Expect.raises(TimeoutException.class,
                () -> gateway.fetch(hang, 30), "a call that never returns");
            return null;
        }, "Gateway.fetch with a 30 ms timeout");
        Expect.isTrue(hang.interrupted.await(WAIT_MS, TimeUnit.MILLISECONDS),
            "After the timeout the abandoned call should be cancelled "
                + "(interrupted), not left running; cancel(true) the Future "
                + "that submit returned (a CompletableFuture never interrupts)");
    }

    @Check(id = "remote-failure-propagates")
    void remoteFailurePropagates() {
        Gateway gateway = new Gateway(daemonPool());
        ExecutionException e = Expect.raises(ExecutionException.class,
            () -> gateway.fetch(() -> {
                throw new IllegalStateException("boom");
            }, 1000), "a remote that throws");
        Expect.isTrue(e.getCause() instanceof IllegalStateException,
            "ExecutionException should carry the remote's own exception");
    }

    @Check(id = "caller-interrupt-cancels")
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
        Expect.isTrue(hang.interrupted.await(WAIT_MS, TimeUnit.MILLISECONDS),
            "Interrupting the caller should cancel the remote call too");
    }

    @Check(id = "no-unbounded-wait", kind = Kind.DESIGN)
    void noUnboundedWait() {
        var gateway = Source.type("Gateway");
        List<Hit> unbounded = new ArrayList<>();
        List<Hit> bounded = new ArrayList<>();
        // get(), join(), await(): no bound; take() and acquire() never have one
        for (String wait : List.of("get", "join", "await", "take", "acquire")) {
            for (Hit h : gateway.calls(wait)) {
                boolean never = wait.equals("take") || wait.equals("acquire");
                if (never || h.args().isEmpty()) {
                    unbounded.add(h);
                } else if (h.args().contains(",") || wait.equals("join")) {
                    bounded.add(h);
                }
            }
        }
        // the timed overloads take (..., timeout, unit)
        for (String wait : List.of("invokeAny", "invokeAll")) {
            for (Hit h : gateway.calls(wait)) {
                (h.args().contains(",") ? bounded : unbounded).add(h);
            }
        }
        Expect.none(unbounded, "Gateway waits without a bound; pass the timeout "
            + "and its unit, e.g. get(timeoutMs, TimeUnit.MILLISECONDS)");
        Expect.isTrue(!bounded.isEmpty(),
            "Gateway.fetch does not pass timeoutMs to a timed wait "
                + "(use the Future.get overload that takes a unit)");
    }

    @Check(id = "cancel-on-timeout", kind = Kind.DESIGN)
    void cancelOnTimeout() {
        var gateway = Source.type("Gateway");
        List<Hit> cancels = gateway.calls("cancel");
        boolean invokeCancels = Stream.concat(gateway.calls("invokeAny").stream(),
                gateway.calls("invokeAll").stream())
            .anyMatch(h -> h.args().contains(","));
        Expect.isTrue(!cancels.isEmpty() || invokeCancels,
            "Gateway.fetch never cancels the abandoned work");
        Expect.isTrue(invokeCancels || cancels.stream()
                .anyMatch(h -> h.args().equals("true")),
            "Gateway cancels with cancel(false), which does not interrupt "
                + "the worker; use cancel(true)");
    }
}
