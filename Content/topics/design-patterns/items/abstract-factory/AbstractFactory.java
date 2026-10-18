import java.util.List;

// [[products
interface BlobStore {
    String put(String key, String body);
}

interface EventBus {
    String publish(String topic, String message);
}
// ]]

// [[factory
interface Infra {
    BlobStore blobs();
    EventBus events();
}
// ]]

// [[local
record LocalInfra() implements Infra {
    public BlobStore blobs() { return (key, body) -> "file:/data/" + key; }
    public EventBus events() {
        return (topic, msg) -> "mem-bus/" + topic + ": " + msg;
    }
}
// ]]

// [[cloud
record CloudInfra(String bucket) implements Infra {
    public BlobStore blobs() {
        return (key, body) -> "s3://" + bucket + "/" + key;
    }
    public EventBus events() {
        return (topic, msg) -> "sns/" + topic + ": " + msg;
    }
}
// ]]

// [[client
final class Uploader {
    private final Infra infra;

    Uploader(Infra infra) { this.infra = infra; }

    String upload(String key, String body) {
        String where = infra.blobs().put(key, body);
        return infra.events().publish("uploaded", where);
    }
}
// ]]

class Main {
    public static void main(String[] args) {
        // [[select
        for (String env : List.of("dev", "prod")) {
            Infra infra = switch (env) {
                case "dev" -> new LocalInfra();
                default -> new CloudInfra("acme-prod");
            };
            System.out.println(new Uploader(infra).upload("q3.csv", "..."));
        }
        // ]]
    }
}
