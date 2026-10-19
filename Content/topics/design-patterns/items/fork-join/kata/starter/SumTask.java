import java.util.concurrent.RecursiveTask;
import java.util.function.BiConsumer;

// Sums data[from, to). Large ranges are split and summed in parallel;
// ranges of at most `threshold` elements are summed directly.
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
        throw new UnsupportedOperationException("TODO");
    }
}
