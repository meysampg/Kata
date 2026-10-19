import java.io.IOException;
import java.util.List;

// A client-side proxy in front of a sharded, replicated store.
final class Ambassador implements KeyValue {
    /**
     * shards: replicas per shard, preferred first.
     * attempts: tries per replica. timeoutMs: limit for one try.
     */
    Ambassador(List<List<KeyValue>> shards, int attempts, long timeoutMs) {
        throw new UnsupportedOperationException("TODO");
    }

    @Override
    public String get(String key) throws IOException {
        throw new UnsupportedOperationException("TODO");
    }
}
