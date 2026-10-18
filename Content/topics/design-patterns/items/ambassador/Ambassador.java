import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

// [[port
interface KeyValue {
    String get(String key) throws IOException;
}
// ]]

// [[node
record Node(String name, boolean up, List<String> trace)
        implements KeyValue {
    public String get(String key) throws IOException {
        trace.add(name);
        if (!up) throw new IOException(name + " is down");
        return name + ":" + key;
    }
}
// ]]

// [[ambassador
final class Ambassador implements KeyValue {
    private final List<List<KeyValue>> shards;

    Ambassador(List<List<KeyValue>> shards) { this.shards = shards; }

    public String get(String key) throws IOException {
        int shard = Math.floorMod(key.hashCode(), shards.size());
        IOException last = null;
        for (KeyValue replica : shards.get(shard)) {
            try {
                return replica.get(key);
            } catch (IOException e) {
                last = e;
            }
        }
        throw new IOException("shard " + shard + " unavailable", last);
    }
}
// ]]

// [[app
final class ProfileService {
    private final KeyValue store;

    ProfileService(KeyValue store) { this.store = store; }

    String load(String user) throws IOException {
        return store.get("user:" + user);
    }
}
// ]]

class Main {
    public static void main(String[] args) throws IOException {
        var trace = new ArrayList<String>();
        // [[wire
        var ambassador = new Ambassador(List.of(
            List.of(new Node("a1", false, trace), new Node("a2", true, trace)),
            List.of(new Node("b1", true, trace), new Node("b2", true, trace))));
        var service = new ProfileService(ambassador);
        // ]]
        for (String user : List.of("1", "2", "3")) {
            System.out.println(service.load(user));
        }
        System.out.println("trace: " + trace);
    }
}
