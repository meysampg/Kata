import java.io.Serializable;

// Meant to be the one shared configuration of the process.
final class AppConfig implements Serializable {
    private static AppConfig instance;

    private AppConfig() { Probe.constructed(); }

    static AppConfig get() {
        if (instance == null) {
            instance = new AppConfig();
        }
        return instance;
    }

    String region() { return "eu-west-1"; }
}
