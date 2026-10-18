import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.concurrent.TimeoutException;

final class FakeClock extends Clock {
    private Instant now = Instant.EPOCH;
    void advance(Duration d) { now = now.plus(d); }
    public Instant instant() { return now; }
    public ZoneId getZone() { return ZoneOffset.UTC; }
    public Clock withZone(ZoneId zone) { return this; }
}

// [[deadline
record Deadline(Clock clock, Instant at) {
    static Deadline in(Clock clock, Duration budget) {
        return new Deadline(clock, clock.instant().plus(budget));
    }
    Duration remaining() { return Duration.between(clock.instant(), at); }

    Duration cap(Duration perCall) throws TimeoutException {
        Duration left = remaining();
        if (left.compareTo(Duration.ZERO) <= 0) {
            throw new TimeoutException("deadline exceeded");
        }
        return perCall.compareTo(left) < 0 ? perCall : left;
    }
}
// ]]

// [[dependency
record Dependency(String name, FakeClock clock, Duration latency) {
    String call(Duration timeout) throws TimeoutException {
        if (latency.compareTo(timeout) > 0) {
            clock.advance(timeout);
            long ms = timeout.toMillis();
            throw new TimeoutException(name + " > " + ms + "ms");
        }
        clock.advance(latency);
        return name + ":ok";
    }
}
// ]]

class Main {
    // [[client
    static void fetch(Deadline deadline, Dependency dep, long perCallMs) {
        try {
            String r = dep.call(deadline.cap(Duration.ofMillis(perCallMs)));
            System.out.println(r + " left=" + deadline.remaining().toMillis());
        } catch (TimeoutException e) {
            System.out.println("timeout: " + e.getMessage());
        }
    }
    // ]]

    static Dependency dep(String n, FakeClock c, long ms) {
        return new Dependency(n, c, Duration.ofMillis(ms));
    }

    public static void main(String[] args) {
        var clock = new FakeClock();
        // [[budget
        var deadline = Deadline.in(clock, Duration.ofMillis(300));
        fetch(deadline, dep("auth", clock, 40), 100);
        fetch(deadline, dep("stock", clock, 120), 200);
        fetch(deadline, dep("price", clock, 400), 250);
        fetch(deadline, dep("audit", clock, 5), 100);
        // ]]
    }
}
