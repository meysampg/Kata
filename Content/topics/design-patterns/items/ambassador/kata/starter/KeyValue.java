import java.io.IOException;

// The port the application already talks to.
interface KeyValue {
    String get(String key) throws IOException;
}

// The application. It must stay unaware of shards, retries and timeouts.
final class ProfileService {
    private final KeyValue store;

    ProfileService(KeyValue store) { this.store = store; }

    String load(String user) throws IOException {
        return store.get("user:" + user);
    }
}
