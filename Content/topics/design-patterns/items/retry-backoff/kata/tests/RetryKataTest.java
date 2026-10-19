import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.Random;
import java.util.function.LongUnaryOperator;
import java.util.function.Supplier;
import kata.*;

class RetryKataTest {
    static final class Waits implements Sleeper {
        final List<Long> ms = new ArrayList<>();
        public void sleep(Duration d) { ms.add(d.toMillis()); }
    }

    static final class Flaky implements Supplier<String> {
        final int failures;
        final RuntimeException error;
        int calls;
        Flaky(int failures, RuntimeException error) {
            this.failures = failures;
            this.error = error;
        }
        public String get() {
            if (calls++ < failures) throw error;
            return "ok";
        }
    }

    static Retry retry(int attempts, LongUnaryOperator jitter, Sleeper s) {
        return new Retry(attempts, 100, 1000, jitter, s);
    }

    @Check(id = "ceiling-doubles-then-caps")
    void ceilingDoublesThenCaps() {
        Retry r = retry(5, c -> c, new Waits());
        List<Long> got = new ArrayList<>();
        for (int a = 1; a <= 6; a++) got.add(r.ceilingMs(a));
        Expect.equal(List.of(100L, 200L, 400L, 800L, 1000L, 1000L), got,
            "ceilings for attempts 1 to 6 (base 100, cap 1000)");
        Expect.equal(1000L, r.ceilingMs(200),
            "the ceiling for attempt 200 (no overflow)");
    }

    @Check(id = "success-first-try")
    void successFirstTry() {
        Waits waits = new Waits();
        Flaky op = new Flaky(0, new TransientException("x"));
        Expect.equal("ok", retry(3, c -> c, waits).call(op), "the result");
        Expect.equal(1, op.calls, "calls to the operation");
        Expect.equal(List.of(), waits.ms, "sleeps before a first-try success");
    }

    @Check(id = "recovers-after-transient")
    void recoversAfterTransient() {
        Waits waits = new Waits();
        Flaky op = new Flaky(2, new TransientException("503"));
        Expect.equal("ok", retry(5, c -> c, waits).call(op), "the result");
        Expect.equal(3, op.calls, "calls to the operation");
        Expect.equal(List.of(100L, 200L), waits.ms, "sleeps between attempts");
    }

    @Check(id = "sleeps-what-jitter-returns")
    void sleepsWhatJitterReturns() {
        Random seeded = new Random(7);
        List<Long> ceilings = new ArrayList<>();
        List<Long> picked = new ArrayList<>();
        LongUnaryOperator jitter = c -> {
            ceilings.add(c);
            long v = (long) (seeded.nextDouble() * (c + 1));
            picked.add(v);
            return v;
        };
        Waits waits = new Waits();
        Flaky op = new Flaky(99, new TransientException("503"));
        Expect.raises(TransientException.class,
            () -> retry(4, jitter, waits).call(op), "an exhausted retry");
        Expect.equal(List.of(100L, 200L, 400L), ceilings,
            "ceilings handed to the jitter function");
        Expect.equal(picked, waits.ms, "sleeps should equal the jittered delays");
    }

    @Check(id = "gives-up-after-max-attempts")
    void givesUpAfterMaxAttempts() {
        Waits waits = new Waits();
        TransientException boom = new TransientException("503");
        Flaky op = new Flaky(99, boom);
        TransientException e = Expect.raises(TransientException.class,
            () -> retry(3, c -> c, waits).call(op), "an exhausted retry");
        Expect.isTrue(e == boom, "the last TransientException should be rethrown as is");
        Expect.equal(3, op.calls, "calls to the operation");
        Expect.equal(2, waits.ms.size(), "sleeps (none after the last attempt)");
    }

    @Check(id = "permanent-is-not-retried")
    void permanentIsNotRetried() {
        Waits waits = new Waits();
        Flaky op = new Flaky(99, new PermanentException("400"));
        Expect.raises(PermanentException.class,
            () -> retry(5, c -> c, waits).call(op), "a permanent failure");
        Expect.equal(1, op.calls, "calls to the operation");
        Expect.equal(List.of(), waits.ms, "sleeps before a permanent failure");
    }

    @Check(id = "single-attempt-never-sleeps")
    void singleAttemptNeverSleeps() {
        Waits waits = new Waits();
        Flaky op = new Flaky(99, new TransientException("503"));
        Expect.raises(TransientException.class,
            () -> retry(1, c -> c, waits).call(op), "maxAttempts = 1");
        Expect.equal(1, op.calls, "calls to the operation");
        Expect.equal(List.of(), waits.ms, "sleeps");
    }

    @Check(id = "no-real-time-or-randomness", kind = Kind.DESIGN)
    void noRealTimeOrRandomness() {
        var retry = Source.type("Retry");
        Expect.none(retry.news("Random"), "Retry creates its own Random");
        Expect.none(retry.calls("random"), "Retry draws its own randomness");
        Expect.none(retry.calls("nextLong"), "Retry draws its own randomness");
        Expect.none(retry.calls("nextDouble"), "Retry draws its own randomness");
        Expect.none(retry.mentions("Thread"), "Retry sleeps on a Thread instead of the Sleeper");
    }

    @Check(id = "retries-only-transient", kind = Kind.DESIGN)
    void retriesOnlyTransient() {
        var call = Source.type("Retry").method("call");
        for (String broad : List.of("Exception", "RuntimeException", "Throwable")) {
            Expect.none(call.mentions(broad),
                "Retry.call catches " + broad + "; retry only TransientException");
        }
    }
}
