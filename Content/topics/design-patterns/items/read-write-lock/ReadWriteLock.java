import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executors;
import java.util.concurrent.locks.ReentrantReadWriteLock;
import java.util.function.Consumer;
import java.util.function.Function;

// [[guarded
final class PriceBook {
    private final ReentrantReadWriteLock lock = new ReentrantReadWriteLock();
    private final Map<String, Integer> prices = new HashMap<>();

    <R> R read(Function<Map<String, Integer>, R> query) {
        lock.readLock().lock();
        try {
            return query.apply(prices);
        } finally {
            lock.readLock().unlock();
        }
    }

    void write(Consumer<Map<String, Integer>> update) {
        lock.writeLock().lock();
        try {
            update.accept(prices);
        } finally {
            lock.writeLock().unlock();
        }
    }
    // ]]
    // [[probe
    int readers() { return lock.getReadLockCount(); }

    boolean writerCouldEnter() {
        boolean ok = lock.writeLock().tryLock();
        if (ok) lock.writeLock().unlock();
        return ok;
    }
    // ]]
}
class Main {
    static void await(CountDownLatch latch) {
        try {
            latch.await();
        } catch (InterruptedException e) {
            throw new IllegalStateException(e);
        }
    }

    public static void main(String[] args) throws Exception {
        var book = new PriceBook();
        book.write(m -> { m.put("tea", 3); m.put("jam", 5); });
        var inside = new CountDownLatch(2);
        var release = new CountDownLatch(1);
        try (var exec = Executors.newVirtualThreadPerTaskExecutor()) {
            // [[readers
            for (String item : new String[] {"tea", "jam"}) {
                exec.submit(() -> book.read(m -> {
                    inside.countDown();
                    await(release);
                    return m.get(item);
                }));
            }
            // ]]
            // [[check
            inside.await();
            System.out.println("readers inside: " + book.readers());
            System.out.println("writer could enter: "
                + book.writerCouldEnter());
            release.countDown();
            // ]]
        }
        // [[after
        System.out.println("writer could enter: "
            + book.writerCouldEnter());
        // ]]
    }
}
