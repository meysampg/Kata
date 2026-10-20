import java.lang.reflect.Field;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.concurrent.BlockingQueue;
import kata.*;

class ProducerConsumerKataTest {
    static long run(List<Integer> amounts, int consumers) {
        return Expect.completesWithin(400,
            () -> new Pipeline().process(amounts, consumers),
            "process(" + amounts.size() + " amounts, " + consumers
            + " consumers)");
    }

    static List<Integer> upTo(int n) {
        List<Integer> all = new ArrayList<>();
        for (int i = 1; i <= n; i++) {
            all.add(i);
        }
        return all;
    }

    @Check(id = "sums-every-amount", timeoutMs = 2000)
    void sumsEveryAmount() {
        Expect.equal(55L, run(upTo(10), 3), "total of 1..10");
        Expect.equal(20100L, run(upTo(200), 5), "total of 1..200");
    }

    @Check(id = "more-consumers-than-amounts", timeoutMs = 2000)
    void moreConsumersThanAmounts() {
        Expect.equal(5L, run(List.of(5), 4), "total of one amount");
    }

    @Check(id = "empty-input", timeoutMs = 2000)
    void emptyInput() {
        Expect.equal(0L, run(List.of(), 2), "total of no amounts");
    }

    @Check(id = "zero-and-negative-amounts-count", timeoutMs = 2000)
    void zeroAndNegativeAmountsCount() {
        Expect.equal(6L, run(List.of(0, -1, 7, 0, 0, 5, -5), 2),
            "total with zero and negative amounts");
        Expect.equal(-1L, run(List.of(Integer.MIN_VALUE, 0,
            Integer.MAX_VALUE, -1, 1, 0), 2),
            "total with Integer.MIN_VALUE and Integer.MAX_VALUE");
    }

    @Check(id = "no-consumer-left-running", timeoutMs = 3000)
    void noConsumerLeftRunning() throws Exception {
        Set<Thread> before = Thread.getAllStackTraces().keySet();
        run(upTo(20), 3);
        List<String> leaked = new ArrayList<>();
        for (Thread t : Thread.getAllStackTraces().keySet()) {
            if (before.contains(t) || t.isDaemon()
                    || t.getName().startsWith("kata")) {
                continue;
            }
            t.join(500);
            if (t.isAlive()) {
                leaked.add(t.getName());
            }
        }
        Expect.isTrue(leaked.isEmpty(), "Consumer threads are still "
            + "running after process() returned: " + leaked);
    }

    @Check(id = "queue-stays-bounded", kind = Kind.DESIGN)
    void queueStaysBounded() throws Exception {
        Pipeline pipeline = new Pipeline();
        Field found = null;
        for (Field f : Pipeline.class.getDeclaredFields()) {
            if (BlockingQueue.class.isAssignableFrom(f.getType())) {
                found = f;
            }
        }
        Expect.isTrue(found != null,
            "Pipeline should keep its BlockingQueue in a field");
        found.setAccessible(true);
        BlockingQueue<?> queue = (BlockingQueue<?>) found.get(pipeline);
        Expect.isTrue(queue.remainingCapacity() + queue.size() <= 1000,
            "The queue must stay bounded so the producer feels backpressure");
    }

    @Check(id = "consumers-stop-on-a-marker", kind = Kind.DESIGN)
    void consumersStopOnAMarker() {
        var pipeline = Source.type("Pipeline");
        // Restoring the flag with Thread.currentThread().interrupt() is fine.
        Set<Integer> restores = new HashSet<>();
        for (Hit h : pipeline.calls("currentThread")) {
            restores.add(h.line());
        }
        Expect.none(pipeline.calls("interrupt").stream()
            .filter(h -> !restores.contains(h.line())).toList(),
            "Pipeline interrupts its "
            + "consumers; send the end of the work through the queue");
        Expect.none(pipeline.calls("poll"), "Pipeline polls the queue; "
            + "consumers should block in take() until a job or the end "
            + "marker arrives");
    }
}
