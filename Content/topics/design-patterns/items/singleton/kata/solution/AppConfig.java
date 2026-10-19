import java.io.Serializable;

final class AppConfig implements Serializable {
    private static final class Holder {
        static final AppConfig INSTANCE = new AppConfig();
    }

    private AppConfig() {
        if (Holder.INSTANCE != null) {
            throw new IllegalStateException("already created");
        }
        Probe.constructed();
    }

    static AppConfig get() { return Holder.INSTANCE; }

    String region() { return "eu-west-1"; }

    private Object readResolve() { return get(); }
}
