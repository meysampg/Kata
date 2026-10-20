import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ForkJoinPool;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import kata.*;

class ForkJoinKataTest {
    static long sum(int[] data, int from, int to, int threshold) {
        ForkJoinPool pool = new ForkJoinPool(4);
        try {
            return Expect.completesWithin(3000,
                () -> pool.invoke(new SumTask(data, from, to, threshold)),
                "SumTask over [" + from + ", " + to + ")");
        } finally {
            pool.shutdown();
        }
    }

    static int[] counting(int n) {
        int[] data = new int[n];
        for (int i = 0; i < n; i++) {
            data[i] = i % 100 - 30;
        }
        return data;
    }

    static long expected(int[] data, int from, int to) {
        long s = 0;
        for (int i = from; i < to; i++) {
            s += data[i];
        }
        return s;
    }

    /** Returns the ranges summed directly, in start order. */
    static List<int[]> leaves(int n, int threshold) {
        List<int[]> seen = Collections.synchronizedList(new ArrayList<>());
        SumTask.onLeaf = (f, t) -> seen.add(new int[] {f, t});
        try {
            sum(new int[n], 0, n, threshold);
        } finally {
            SumTask.onLeaf = (f, t) -> { };
        }
        List<int[]> sorted = new ArrayList<>(seen);
        sorted.sort((a, b) -> Integer.compare(a[0], b[0]));
        return sorted;
    }

    @Check(id = "sums-edge-ranges", timeoutMs = 5000)
    void sumsEdgeRanges() {
        int[] data = counting(50);
        Expect.equal(0L, sum(data, 0, 0, 4), "an empty range");
        Expect.equal(expected(data, 7, 8), sum(data, 7, 8, 4),
            "a single element");
        Expect.equal(expected(data, 0, 50), sum(data, 0, 50, 1000),
            "a range below the threshold");
        Expect.equal(expected(data, 5, 43), sum(data, 5, 43, 4),
            "a range that does not start at 0");
        Expect.equal(expected(data, 0, 50), sum(data, 0, 50, 1),
            "a threshold of 1");
    }

    @Check(id = "sums-do-not-overflow", timeoutMs = 5000)
    void sumsDoNotOverflow() {
        int[] big = new int[100];
        java.util.Arrays.fill(big, Integer.MAX_VALUE);
        Expect.equal(100L * Integer.MAX_VALUE, sum(big, 0, 100, 8),
            "100 elements of Integer.MAX_VALUE");
    }

    @Check(id = "matches-a-sequential-sum", timeoutMs = 5000)
    void matchesASequentialSum() {
        int[] data = counting(1_000_000);
        Expect.equal(expected(data, 0, data.length),
            sum(data, 0, data.length, 1_000), "one million elements");
    }

    @Check(id = "leaves-tile-the-range", timeoutMs = 5000)
    void leavesTileTheRange() {
        for (int[] c : new int[][] {{1000, 100}, {1001, 7}, {64, 1}}) {
            List<int[]> seen = leaves(c[0], c[1]);
            int next = 0;
            for (int[] leaf : seen) {
                Expect.equal(next, leaf[0], "start of the next range for "
                    + c[0] + " elements, threshold " + c[1]);
                Expect.isTrue(leaf[1] - leaf[0] <= c[1],
                    "Range [" + leaf[0] + ", " + leaf[1] + ") is longer "
                    + "than the threshold " + c[1]);
                next = leaf[1];
            }
            Expect.equal(c[0], next, "end of the last range for "
                + c[0] + " elements, threshold " + c[1]);
        }
    }

    @Check(id = "small-ranges-are-not-split", timeoutMs = 5000)
    void smallRangesAreNotSplit() {
        List<int[]> seen = leaves(100, 100);
        Expect.equal(1, seen.size(), "ranges for 100 elements, threshold 100");
        Expect.equal(0, seen.get(0)[0], "start of the only range");
        Expect.equal(100, seen.get(0)[1], "end of the only range");
        Expect.isTrue(leaves(1000, 100).size() <= 40,
            "1000 elements with threshold 100 were cut into too many tiny "
            + "ranges; stop splitting as soon as a range fits the threshold");
    }

    @Check(id = "halves-run-at-the-same-time", timeoutMs = 5000)
    void halvesRunAtTheSameTime() {
        CountDownLatch two = new CountDownLatch(2);
        AtomicBoolean waited = new AtomicBoolean();
        AtomicBoolean overlapped = new AtomicBoolean();
        SumTask.onLeaf = (f, t) -> {
            two.countDown();
            if (waited.compareAndSet(false, true)) {
                try {
                    if (two.await(1500, TimeUnit.MILLISECONDS)) {
                        overlapped.set(true);
                    }
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                }
            }
        };
        try {
            sum(counting(4000), 0, 4000, 100);
        } finally {
            SumTask.onLeaf = (f, t) -> { };
        }
        Expect.isTrue(overlapped.get(), "No two ranges were ever summed at "
            + "the same time: fork() one half, compute() the other, then "
            + "join() the first");
    }

    static long pos(Hit h) {
        return h.line() * 10_000L + h.column();
    }

    @Check(id = "splits-with-fork-and-join", kind = Kind.DESIGN)
    void splitsWithForkAndJoin() {
        var compute = Source.type("SumTask").method("compute");
        if (!compute.calls("invokeAll").isEmpty()) {
            return;
        }
        var forks = compute.calls("fork");
        var joins = compute.calls("join");
        Expect.isTrue(!forks.isEmpty() && !joins.isEmpty(), "compute() should "
            + "split the work with fork() and join(), or with invokeAll()");
        long fork = forks.stream().mapToLong(ForkJoinKataTest::pos).min()
            .getAsLong();
        long join = joins.stream().mapToLong(ForkJoinKataTest::pos).min()
            .getAsLong();
        var own = new ArrayList<Hit>(compute.calls("compute"));
        own.addAll(compute.calls("invoke"));
        boolean between = own.stream().mapToLong(ForkJoinKataTest::pos)
            .anyMatch(p -> p > fork && p < join);
        Expect.isTrue(between, "compute() should work on one half itself "
            + "between fork() and join(); joining first, or forking both "
            + "halves, leaves this worker idle");
    }

    @Check(id = "no-threads-of-its-own", kind = Kind.DESIGN)
    void noThreadsOfItsOwn() {
        var task = Source.type("SumTask");
        Expect.none(task.news("Thread"), "SumTask creates threads itself");
        Expect.none(task.mentions("Executors"),
            "SumTask runs its work on its own executor");
        Expect.none(task.mentions("parallelStream"),
            "SumTask hands the work to a parallel stream");
        Expect.none(task.mentions("ForkJoinPool"),
            "SumTask should leave the pool to its caller");
    }
}
