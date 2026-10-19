// Family 1: everything on the local machine.
// put("a.csv", ..)   -> "file:/data/a.csv"
// publish("t", "m")  -> "mem-bus/t: m"
record LocalInfra() implements Infra {
    public BlobStore blobs() {
        throw new UnsupportedOperationException("TODO");
    }
    public EventBus events() {
        throw new UnsupportedOperationException("TODO");
    }
}

// Family 2: everything in the cloud, in one bucket (never blank).
// put("a.csv", ..)   -> "s3://<bucket>/a.csv"
// publish("t", "m")  -> "sns/t: m"
record CloudInfra(String bucket) implements Infra {
    public BlobStore blobs() {
        throw new UnsupportedOperationException("TODO");
    }
    public EventBus events() {
        throw new UnsupportedOperationException("TODO");
    }
}

// Stores the body, then publishes the location on topic "uploaded".
final class Uploader {
    Uploader(Infra infra) { }

    String upload(String key, String body) {
        throw new UnsupportedOperationException("TODO");
    }
}

// "dev" -> LocalInfra, "prod" -> CloudInfra("acme-prod"), else IAE.
final class Infras {
    private Infras() { }

    static Infra forEnv(String env) {
        throw new UnsupportedOperationException("TODO");
    }
}
