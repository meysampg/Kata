import java.io.IOException;
import java.util.List;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;

final class Ambassador implements KeyValue {
    private final List<List<KeyValue>> shards;
    private final int attempts;
    private final long timeoutMs;

    Ambassador(List<List<KeyValue>> shards, int attempts, long timeoutMs) {
        this.shards = shards;
        this.attempts = attempts;
        this.timeoutMs = timeoutMs;
    }

    @Override
    public String get(String key) throws IOException {
        int shard = Math.floorMod(key.hashCode(), shards.size());
        IOException last = null;
        for (KeyValue replica : shards.get(shard)) {
            for (int i = 0; i < attempts; i++) {
                try {
                    return attempt(replica, key);
                } catch (IOException e) {
                    last = e;
                }
            }
        }
        throw new IOException("shard " + shard + " unavailable", last);
    }

    private String attempt(KeyValue replica, String key) throws IOException {
        CompletableFuture<String> call = new CompletableFuture<>();
        Thread.ofVirtual().start(() -> {
            try {
                call.complete(replica.get(key));
            } catch (Throwable e) {
                call.completeExceptionally(e);
            }
        });
        try {
            return call.get(timeoutMs, TimeUnit.MILLISECONDS);
        } catch (TimeoutException e) {
            call.cancel(true);
            throw new IOException("timed out after " + timeoutMs + " ms", e);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IOException("interrupted", e);
        } catch (ExecutionException e) {
            if (e.getCause() instanceof IOException io) {
                throw io;
            }
            if (e.getCause() instanceof RuntimeException re) {
                throw re;
            }
            throw new IOException(e.getCause());
        }
    }
}
