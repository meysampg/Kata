import java.util.ArrayList;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.function.Supplier;

// [[servant
final class Counter {
    private int total;

    int add(int n) { return total += n; }
}
// ]]

// [[active
final class ActiveCounter implements AutoCloseable {
    private static final Runnable STOP = () -> { };
    private final Counter servant = new Counter();
    private final BlockingQueue<Runnable> inbox = new LinkedBlockingQueue<>();
    private final Thread scheduler = Thread.ofPlatform().start(this::loop);

    CompletableFuture<Integer> add(int n) {
        return enqueue(() -> servant.add(n));
    }

    private <T> CompletableFuture<T> enqueue(Supplier<T> request) {
        var result = new CompletableFuture<T>();
        inbox.add(() -> {
            try { result.complete(request.get()); }
            catch (RuntimeException e) { result.completeExceptionally(e); }
        });
        return result;
    }
    // ]]

    // [[loop
    private void loop() {
        try {
            for (Runnable r; (r = inbox.take()) != STOP; ) r.run();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }

    @Override
    public void close() {
        inbox.add(STOP);
        try {
            scheduler.join();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
    // ]]
}

class Main {
    public static void main(String[] args) throws Exception {
        try (var counter = new ActiveCounter()) {
            // [[async
            var a = counter.add(1);
            var b = counter.add(2);
            var c = counter.add(3);
            System.out.println(a.get() + " " + b.get() + " " + c.get());
            // ]]
            // [[callers
            var callers = new ArrayList<Thread>();
            for (int t = 0; t < 4; t++) {
                callers.add(Thread.ofPlatform().start(() -> {
                    for (int i = 0; i < 100; i++) counter.add(1);
                }));
            }
            for (Thread t : callers) t.join();
            System.out.println("total = " + counter.add(0).get());
            // ]]
        }
    }
}
