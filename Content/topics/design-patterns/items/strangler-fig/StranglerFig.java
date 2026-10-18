import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

interface Backend { String handle(String userId, String path); }

// [[facade
final class StranglerFacade implements Backend {
    private final Backend legacy;
    private final Backend modern;
    private final Map<String, Integer> migrated = new LinkedHashMap<>();

    StranglerFacade(Backend legacy, Backend modern) {
        this.legacy = legacy;
        this.modern = modern;
    }

    StranglerFacade migrate(String prefix, int percent) {
        migrated.put(prefix, percent);
        return this;
    }

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
// ]]

class Main {
    public static void main(String[] args) {
        // [[backends
        Backend legacy = (u, p) -> "legacy " + p;
        Backend modern = (u, p) -> "modern " + p;
        // ]]
        // [[rules
        var facade = new StranglerFacade(legacy, modern)
            .migrate("/customers", 100)
            .migrate("/invoices", 50);
        // ]]
        // [[traffic
        List<String> out = new ArrayList<>();
        for (String user : List.of("alice", "bob", "carol", "dave")) {
            out.add(user + ": " + facade.handle(user, "/invoices/1"));
        }
        out.add(facade.handle("u1", "/customers/9"));
        out.add(facade.handle("u1", "/reports/q3"));
        // ]]
        out.forEach(System.out::println);
    }
}
