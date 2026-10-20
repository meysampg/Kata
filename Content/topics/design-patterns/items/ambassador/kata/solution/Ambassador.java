import java.io.IOException;
import java.io.InterruptedIOException;
import java.util.List;
import java.util.concurrent.FutureTask;
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

    // One try on its own virtual thread, bounded by timeoutMs. A FutureTask
    // (unlike a CompletableFuture) interrupts the worker when cancelled.
    private String attempt(KeyValue replica, String key) throws IOException {
        FutureTask<String> call = new FutureTask<>(() -> replica.get(key));
        Thread.ofVirtual().start(call);
        try {
            return call.get(timeoutMs, TimeUnit.MILLISECONDS);
        } catch (TimeoutException e) {
            throw new IOException("timed out after " + timeoutMs + " ms", e);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new InterruptedIOException("interrupted");
        } catch (ExecutionException e) {
            if (e.getCause() instanceof IOException io) {
                throw io;
            }
            if (e.getCause() instanceof RuntimeException re) {
                throw re;
            }
            throw new IOException(e.getCause());
        } finally {
            call.cancel(true);
        }
    }
}
