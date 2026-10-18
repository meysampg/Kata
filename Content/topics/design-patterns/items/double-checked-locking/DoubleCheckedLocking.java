import java.util.ArrayList;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;

// [[dcl
final class Config {
    static final AtomicInteger CREATED = new AtomicInteger();
    private static volatile Config instance;
    private final Map<String, String> settings;

    private Config() {
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

    String mode() { return settings.get("mode"); }
}
// ]]

// [[holder
final class Registry {
    private Registry() { }

    private static final class Holder {
        static final Registry INSTANCE = new Registry();
    }

    static Registry get() { return Holder.INSTANCE; }
}
// ]]

class Main {
    public static void main(String[] args) throws Exception {
        var seen = new Config[8];
        var threads = new ArrayList<Thread>();
        // [[race
        for (int i = 0; i < seen.length; i++) {
            int n = i;
            threads.add(Thread.ofPlatform()
                .start(() -> seen[n] = Config.get()));
        }
        for (Thread t : threads) t.join();
        // ]]
        // [[report
        boolean same = true;
        for (Config c : seen) same &= c == seen[0];
        System.out.println("same instance: " + same);
        System.out.println("constructed: " + Config.CREATED.get());
        System.out.println("mode: " + seen[0].mode());
        System.out.println("holder: " + (Registry.get() == Registry.get()));
        // ]]
    }
}
