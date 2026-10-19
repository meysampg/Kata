import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.locks.ReentrantReadWriteLock;
import java.util.function.Function;

// Many threads read prices; a missing price is loaded once and cached.
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
            lock.writeLock().lock();
            try {
                Integer loaded = loader.apply(sku);
                prices.put(sku, loaded);
                return loaded;
            } finally {
                lock.writeLock().unlock();
            }
        } finally {
            lock.readLock().unlock();
        }
    }
}
