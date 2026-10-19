import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Objects;

final class StranglerFacade implements Backend {
    private final Backend legacy;
    private final Backend modern;
    private final Map<String, Integer> migrated = new LinkedHashMap<>();

    StranglerFacade(Backend legacy, Backend modern) {
        this.legacy = Objects.requireNonNull(legacy, "legacy");
        this.modern = Objects.requireNonNull(modern, "modern");
    }

    StranglerFacade migrate(String prefix, int percent) {
        migrated.put(prefix, percent);
        return this;
    }

    @Override
    public String handle(String userId, String path) {
        for (var rule : migrated.entrySet()) {
            if (path.startsWith(rule.getKey())) {
                int bucket = Math.floorMod(userId.hashCode(), 100);
                return bucket < rule.getValue()
                    ? modern.handle(userId, path)
                    : legacy.handle(userId, path);
            }
        }
        return legacy.handle(userId, path);
    }
}
