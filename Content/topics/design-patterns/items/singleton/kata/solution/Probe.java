import java.util.concurrent.atomic.AtomicInteger;

// Test seam: keep it as it is. The constructor of AppConfig must call
// Probe.constructed() exactly once per instance it creates.
final class Probe {
    static final AtomicInteger CREATED = new AtomicInteger();
    static volatile Runnable onConstruct = () -> { };

    private Probe() { }

    static void constructed() {
        onConstruct.run();
        CREATED.incrementAndGet();
    }
}
