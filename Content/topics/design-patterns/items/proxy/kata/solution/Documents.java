import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.function.Supplier;

interface Documents {
    String read(String id);
}

final class RemoteDocuments implements Documents {
    RemoteDocuments() { /* connect */ }

    public String read(String id) { return "body of " + id; }
}

final class CachedDocuments implements Documents {
    private final Supplier<Documents> factory;
    private final Map<String, String> cache = new ConcurrentHashMap<>();
    private Documents real; // guarded by this

    CachedDocuments(Supplier<Documents> factory) {
        this.factory = factory;
    }

    public String read(String id) {
        return cache.computeIfAbsent(id, k -> real().read(k));
    }

    private synchronized Documents real() {
        if (real == null) real = factory.get();
        return real;
    }
}
