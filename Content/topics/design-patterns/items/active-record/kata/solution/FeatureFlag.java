import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.TreeMap;

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
        if (name == null || name.isBlank()) {
            throw new IllegalArgumentException("name");
        }
        checkPercent(percent);
        return new FeatureFlag(name, false, percent);
    }

    static Optional<FeatureFlag> find(String name) {
        Row row = TABLE.get(name);
        if (row == null) return Optional.empty();
        var flag = new FeatureFlag(name, row.enabled(), row.percent());
        flag.persisted = true;
        return Optional.of(flag);
    }

    static List<FeatureFlag> all() {
        return TABLE.keySet().stream()
            .map(n -> find(n).orElseThrow()).toList();
    }

    void toggle() { enabled = !enabled; }

    void rollout(int percent) {
        checkPercent(percent);
        this.percent = percent;
    }

    FeatureFlag save() {
        if (!persisted && TABLE.containsKey(name)) {
            throw new IllegalStateException("already exists: " + name);
        }
        TABLE.put(name, new Row(enabled, percent));
        persisted = true;
        return this;
    }

    void delete() {
        TABLE.remove(name);
        persisted = false;
    }

    private static void checkPercent(int percent) {
        if (percent < 0 || percent > 100) {
            throw new IllegalArgumentException("percent: " + percent);
        }
    }

    String name() { return name; }
    boolean enabled() { return enabled; }
    int percent() { return percent; }
    boolean persisted() { return persisted; }
}
