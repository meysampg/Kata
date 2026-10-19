import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.locks.ReentrantReadWriteLock;
import java.util.function.Function;

final class PriceBook {
    private final ReentrantReadWriteLock lock = new ReentrantReadWriteLock();
    private final Map<String, Integer> prices = new HashMap<>();
    private final Function<String, Integer> loader;

    PriceBook(Function<String, Integer> loader) {
        this.loader = loader;
    }

    void put(String sku, int price) {
        lock.writeLock().lock();
        try {
            prices.put(sku, price);
        } finally {
            lock.writeLock().unlock();
        }
    }

    Integer price(String sku) {
        lock.readLock().lock();
        try {
            Integer cached = prices.get(sku);
            if (cached != null) {
                return cached;
            }
        } finally {
            lock.readLock().unlock();
        }
        // A read lock cannot be upgraded: release it, then take the
        // write lock and look again, because another writer may have won.
        lock.writeLock().lock();
        try {
            Integer cached = prices.get(sku);
            if (cached == null) {
                cached = loader.apply(sku);
                prices.put(sku, cached);
            }
            return cached;
        } finally {
            lock.writeLock().unlock();
        }
    }
}
