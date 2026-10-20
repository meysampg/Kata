import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.Executor;
import java.util.concurrent.RejectedExecutionException;

final class MiniPool implements Executor {
    private static final Runnable STOP = () -> { };
    private final BlockingQueue<Runnable> queue;
    private final List<Thread> workers = new ArrayList<>();
    private boolean closed; // guarded by this

    MiniPool(int threads, int capacity) {
        queue = new ArrayBlockingQueue<>(capacity);
        for (int i = 0; i < threads; i++) {
            workers.add(Thread.ofPlatform().start(this::loop));
        }
    }

    @Override
    public synchronized void execute(Runnable task) {
        // Check and queue under one lock, so no task can slip in behind
        // the stop markers once shutdown() has begun.
        if (closed) {
            throw new RejectedExecutionException("pool is shut down");
        }
        try {
            queue.put(task);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new RejectedExecutionException(e);
        }
    }

    void shutdown() throws InterruptedException {
        synchronized (this) {
            closed = true;
        }
        // One stop marker per worker, queued behind the pending tasks.
        for (int i = 0; i < workers.size(); i++) {
            queue.put(STOP);
        }
        for (Thread worker : workers) {
            worker.join();
        }
    }

    private void loop() {
        try {
            for (Runnable r; (r = queue.take()) != STOP; ) {
                try {
                    r.run();
                } catch (RuntimeException e) {
                    // A failing task must not kill its worker.
                }
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
}
