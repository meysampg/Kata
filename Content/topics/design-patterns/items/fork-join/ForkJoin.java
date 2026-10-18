import java.util.concurrent.ForkJoinPool;
import java.util.concurrent.RecursiveTask;

// [[task
@SuppressWarnings("serial")
final class SumTask extends RecursiveTask<Long> {
    private static final int THRESHOLD = 1_000;
    private final int[] data;
    private final int from, to;

    SumTask(int[] data, int from, int to) {
        this.data = data;
        this.from = from;
        this.to = to;
    }
    // ]]

    // [[compute
    @Override
    protected Long compute() {
        if (to - from <= THRESHOLD) {
            long sum = 0;
            for (int i = from; i < to; i++) sum += data[i];
            return sum;
        }
        int mid = (from + to) >>> 1;
        var left = new SumTask(data, from, mid);
        var right = new SumTask(data, mid, to);
        left.fork();
        long r = right.compute();
        return left.join() + r;
    }
    // ]]
}

class Main {
    public static void main(String[] args) {
        int[] data = new int[1_000_000];
        for (int i = 0; i < data.length; i++) data[i] = i % 100;
        long sequential = 0;
        for (int v : data) sequential += v;
        // [[invoke
        try (var pool = new ForkJoinPool(4)) {
            long parallel = pool.invoke(new SumTask(data, 0, data.length));
            System.out.println("parallelism: " + pool.getParallelism());
            System.out.println("sum: " + parallel);
            System.out.println("matches: " + (parallel == sequential));
        }
        // ]]
    }
}
