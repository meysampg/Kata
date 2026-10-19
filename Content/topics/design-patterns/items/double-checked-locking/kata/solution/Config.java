import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;

final class Config {
    static final AtomicInteger CREATED = new AtomicInteger();
    // Test hook: runs at the start of the constructor. Keep it.
    static volatile Runnable onConstruct = () -> { };

    private static volatile Config instance;
    private final Map<String, String> settings;

    private Config() {
        onConstruct.run();
        CREATED.incrementAndGet();
        settings = Map.of("mode", "prod");
    }

    static Config get() {
        Config local = instance;
        if (local == null) {
            synchronized (Config.class) {
                local = instance;
                if (local == null) {
                    instance = local = new Config();
                }
            }
        }
        return local;
    }

    String mode() {
        return settings.get("mode");
    }
}
