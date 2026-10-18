import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Set;
import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Executor;
import java.util.concurrent.RejectedExecutionException;

// [[pool
final class MiniPool implements Executor {
    private static final Runnable STOP = () -> { };
    private final BlockingQueue<Runnable> queue;
    private final List<Thread> workers = new ArrayList<>();

    MiniPool(int threads, int capacity) {
        queue = new ArrayBlockingQueue<>(capacity);
        for (int i = 0; i < threads; i++) {
            workers.add(Thread.ofPlatform().start(this::loop));
        }
    }

    @Override
    public void execute(Runnable task) {
        try {
            queue.put(task);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new RejectedExecutionException(e);
        }
    }
    // ]]

    // [[worker
    private void loop() {
        try {
            for (Runnable r; (r = queue.take()) != STOP; ) {
                try { r.run(); } catch (RuntimeException e) { /* log */ }
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
    // ]]

    // [[shutdown
    void shutdown() throws InterruptedException {
        for (int i = 0; i < workers.size(); i++) queue.put(STOP);
        for (Thread w : workers) w.join();
    }
    // ]]
}

class Main {
    public static void main(String[] args) throws Exception {
        var pool = new MiniPool(3, 4);
        int[] squares = new int[8];
        Set<String> used = ConcurrentHashMap.newKeySet();
        // [[submit
        for (int i = 0; i < squares.length; i++) {
            int n = i;
            pool.execute(() -> {
                squares[n] = n * n;
                used.add(Thread.currentThread().getName());
            });
        }
        // ]]
        // [[join
        pool.shutdown();
        System.out.println(Arrays.toString(squares));
        System.out.println("threads used <= 3: " + (used.size() <= 3));
        // ]]
    }
}
