import java.util.concurrent.RecursiveTask;
import java.util.function.BiConsumer;

@SuppressWarnings("serial")
final class SumTask extends RecursiveTask<Long> {
    // Test hook: called with (from, to) for every range summed directly.
    // Keep it.
    static volatile BiConsumer<Integer, Integer> onLeaf = (from, to) -> { };

    private final int[] data;
    private final int from;
    private final int to;
    private final int threshold;

    SumTask(int[] data, int from, int to, int threshold) {
        this.data = data;
        this.from = from;
        this.to = to;
        this.threshold = threshold;
    }

    @Override
    protected Long compute() {
        if (to - from <= threshold) {
            onLeaf.accept(from, to);
            long sum = 0;
            for (int i = from; i < to; i++) {
                sum += data[i];
            }
            return sum;
        }
        int mid = (from + to) >>> 1;
        var left = new SumTask(data, from, mid, threshold);
        var right = new SumTask(data, mid, to, threshold);
        left.fork();
        long rightSum = right.compute();
        return left.join() + rightSum;
    }
}
