import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.TreeMap;

// A row that knows how to save itself. The table is static, in memory.
final class FeatureFlag {
    private record Row(boolean enabled, int percent) { }

    private static final Map<String, Row> TABLE = new TreeMap<>();

    private final String name;
    private boolean enabled;
    private int percent;
    private boolean persisted;

    private FeatureFlag(String name, boolean enabled, int percent) {
        this.name = name;
        this.enabled = enabled;
        this.percent = percent;
    }

    /** Test hook: empties the table. */
    static void reset() { TABLE.clear(); }

    static FeatureFlag create(String name, int percent) {
        throw new UnsupportedOperationException("TODO");
    }

    static Optional<FeatureFlag> find(String name) {
        throw new UnsupportedOperationException("TODO");
    }

    static List<FeatureFlag> all() {
        throw new UnsupportedOperationException("TODO");
    }

    void toggle() {
        throw new UnsupportedOperationException("TODO");
    }

    void rollout(int percent) {
        throw new UnsupportedOperationException("TODO");
    }

    FeatureFlag save() {
        throw new UnsupportedOperationException("TODO");
    }

    void delete() {
        throw new UnsupportedOperationException("TODO");
    }

    String name() { return name; }
    boolean enabled() { return enabled; }
    int percent() { return percent; }
    boolean persisted() { return persisted; }
}
