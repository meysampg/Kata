import java.util.concurrent.atomic.AtomicLong;

// [[enumSingleton
enum Ids {
    INSTANCE;

    private final AtomicLong next = new AtomicLong();

    long next() { return next.incrementAndGet(); }
}
// ]]

// [[holder
final class AppConfig {
    static int created;

    private AppConfig() { created++; }

    private static final class Holder {
        static final AppConfig INSTANCE = new AppConfig();
    }

    static AppConfig get() { return Holder.INSTANCE; }

    String region() { return "eu-west-1"; }
}
// ]]

class Main {
    public static void main(String[] args) {
        // [[useEnum
        System.out.println(Ids.INSTANCE.next());
        System.out.println(Ids.INSTANCE.next());
        // ]]
        // [[useHolder
        System.out.println("created before: " + AppConfig.created);
        var a = AppConfig.get();
        var b = AppConfig.get();
        System.out.println("same: " + (a == b));
        System.out.println("created after: " + AppConfig.created);
        // ]]
    }
}
