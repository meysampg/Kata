import java.util.concurrent.BlockingQueue;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.function.Supplier;

final class ActiveCounter implements AutoCloseable {
    private static final Runnable STOP = () -> { };
    private final Counter servant;
    private final BlockingQueue<Runnable> inbox = new LinkedBlockingQueue<>();
    private final Thread scheduler;
    private volatile boolean closed;

    ActiveCounter(Counter servant) {
        this.servant = servant;
        scheduler = Thread.ofPlatform().start(this::loop);
    }

    CompletableFuture<Integer> add(int n) {
        return enqueue(() -> servant.add(n));
    }

    CompletableFuture<Integer> total() {
        return enqueue(servant::total);
    }

    private CompletableFuture<Integer> enqueue(Supplier<Integer> request) {
        if (closed) {
            throw new IllegalStateException("closed");
        }
        var result = new CompletableFuture<Integer>();
        inbox.add(() -> {
            try {
                result.complete(request.get());
            } catch (RuntimeException e) {
                result.completeExceptionally(e);
            }
        });
        return result;
    }

    private void loop() {
        try {
            for (Runnable r; (r = inbox.take()) != STOP; ) {
                r.run();
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }

    @Override
    public void close() {
        closed = true;
        inbox.add(STOP);
        try {
            scheduler.join();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
}
