import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;

// Everyone calls Config.get(). It must build exactly one Config, and it
// must not make callers queue up once the Config exists.
final class Config {
    static final AtomicInteger CREATED = new AtomicInteger();
    // Test hook: runs at the start of the constructor. Keep it.
    static volatile Runnable onConstruct = () -> { };

    private static Config instance;
    private final Map<String, String> settings;

    private Config() {
        onConstruct.run();
        CREATED.incrementAndGet();
        settings = Map.of("mode", "prod");
    }

    static Config get() {
        if (instance == null) {
            synchronized (Config.class) {
                instance = new Config();
            }
        }
        return instance;
    }

    String mode() {
        return settings.get("mode");
    }
}
