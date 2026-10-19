record LocalInfra() implements Infra {
    public BlobStore blobs() { return (key, body) -> "file:/data/" + key; }
    public EventBus events() {
        return (topic, msg) -> "mem-bus/" + topic + ": " + msg;
    }
}

record CloudInfra(String bucket) implements Infra {
    CloudInfra {
        if (bucket == null || bucket.isBlank()) {
            throw new IllegalArgumentException("bucket");
        }
    }

    public BlobStore blobs() {
        return (key, body) -> "s3://" + bucket + "/" + key;
    }
    public EventBus events() {
        return (topic, msg) -> "sns/" + topic + ": " + msg;
    }
}

final class Uploader {
    private final Infra infra;

    Uploader(Infra infra) { this.infra = infra; }

    String upload(String key, String body) {
        String where = infra.blobs().put(key, body);
        return infra.events().publish("uploaded", where);
    }
}

final class Infras {
    private Infras() { }

    static Infra forEnv(String env) {
        return switch (env) {
            case "dev" -> new LocalInfra();
            case "prod" -> new CloudInfra("acme-prod");
            default -> throw new IllegalArgumentException("env: " + env);
        };
    }
}
