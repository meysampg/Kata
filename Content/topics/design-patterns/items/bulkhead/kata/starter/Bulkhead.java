import java.util.function.Supplier;

// One compartment per dependency: at most maxConcurrent calls inside.
final class Bulkhead {
    private final String name;
    private final int maxConcurrent;

    Bulkhead(String name, int maxConcurrent) {
        this.name = name;
        this.maxConcurrent = maxConcurrent;
    }

    <T> T call(Supplier<T> op) {
        throw new UnsupportedOperationException("TODO");
    }
}
