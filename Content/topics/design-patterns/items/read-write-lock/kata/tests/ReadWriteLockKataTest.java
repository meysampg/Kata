import java.lang.reflect.Field;
import java.lang.reflect.Modifier;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.locks.ReentrantReadWriteLock;
import kata.*;

class ReadWriteLockKataTest {
    static ReentrantReadWriteLock lockOf(PriceBook book) throws Throwable {
        Field f = Types.onlyFieldOfType(PriceBook.class,
            ReentrantReadWriteLock.class);
        f.setAccessible(true);
        return (ReentrantReadWriteLock) f.get(book);
    }

    @Check(id = "cached-price-is-returned", timeoutMs = 3000)
    void cachedPriceIsReturned() {
        var loads = new AtomicInteger();
        var book = new PriceBook(sku -> loads.incrementAndGet());
        book.put("apple", 3);
        Expect.equal(3, Expect.completesWithin(1000,
            () -> book.price("apple"), "price(\"apple\") for a cached sku"),
            "price(\"apple\")");
        Expect.equal(0, loads.get(), "loader calls for a cached sku");
    }

    @Check(id = "miss-loads-and-caches", timeoutMs = 3000)
    void missLoadsAndCaches() {
        var loads = new AtomicInteger();
        var book = new PriceBook(sku -> 40 + loads.incrementAndGet());
        Expect.equal(41, Expect.completesWithin(1000,
            () -> book.price("pear"), "price(\"pear\") for a missing sku"),
            "first price(\"pear\")");
        Expect.equal(41, Expect.completesWithin(1000,
            () -> book.price("pear"), "second price(\"pear\")"),
            "second price(\"pear\")");
        Expect.equal(1, loads.get(), "loader calls for one sku");
    }

    @Check(id = "concurrent-misses-load-once", timeoutMs = 5000)
    void concurrentMissesLoadOnce() {
        var loads = new AtomicInteger();
        var book = new PriceBook(sku -> {
            Stress.pause(10);
            return 40 + loads.incrementAndGet();
        });
        var prices = Expect.completesWithin(2500,
            () -> Stress.race(8, () -> book.price("plum")),
            "8 threads asking for the same missing sku");
        Expect.equal(1, loads.get(), "loader calls for 8 simultaneous misses");
        Expect.equal(8L, prices.stream().filter(p -> p == 41).count(),
            "threads that got the loaded price");
    }

    @Check(id = "readers-share-the-lock", timeoutMs = 3000)
    void readersShareTheLock() throws Throwable {
        var book = new PriceBook(sku -> 0);
        book.put("fig", 9);
        var rw = lockOf(book);
        try (var reader = Stress.holdLock(rw.readLock())) {
            Expect.equal(9, Expect.completesWithin(500,
                () -> book.price("fig"),
                "price(\"fig\") while another thread is reading"),
                "price(\"fig\")");
        }
    }

    @Check(id = "loader-failure-releases-locks", timeoutMs = 4000)
    void loaderFailureReleasesLocks() throws Throwable {
        var book = new PriceBook(sku -> {
            throw new IllegalStateException("catalog down");
        });
        var rw = lockOf(book);
        var thrown = Expect.completesWithin(1000, () -> {
            try {
                book.price("kiwi");
                return null;
            } catch (IllegalStateException e) {
                return e;
            }
        }, "price(\"kiwi\") with a failing loader");
        Expect.isTrue(thrown != null && "catalog down".equals(thrown.getMessage()),
            "the loader's IllegalStateException should reach the caller");
        Expect.equal(0, rw.getReadLockCount(), "read locks still held");
        Expect.isTrue(!rw.isWriteLocked(), "the write lock is still held");
        Expect.completesWithin(1000, () -> {
            book.put("kiwi", 5);
            return null;
        }, "put after a failed load");
    }

    @Check(id = "loader-runs-under-the-write-lock", kind = Kind.DESIGN,
        timeoutMs = 3000)
    void loaderRunsUnderTheWriteLock() throws Throwable {
        var rwRef = new java.util.concurrent.atomic.AtomicReference<
            ReentrantReadWriteLock>();
        var seen = new AtomicInteger(-1);
        var book = new PriceBook(sku -> {
            var rw = rwRef.get();
            boolean ok = rw.getReadHoldCount() == 0
                && rw.isWriteLockedByCurrentThread();
            seen.set(ok ? 1 : 0);
            return 1;
        });
        rwRef.set(lockOf(book));
        Expect.completesWithin(1000, () -> book.price("lime"),
            "price(\"lime\") for a missing sku");
        Expect.isTrue(seen.get() != -1, "the loader was never called");
        Expect.isTrue(seen.get() == 1, "the loader should run holding the "
            + "write lock and no read lock");
    }

    @Check(id = "lock-is-private-final", kind = Kind.DESIGN)
    void lockIsPrivateFinal() {
        Field f = Types.onlyFieldOfType(PriceBook.class,
            ReentrantReadWriteLock.class);
        int m = f.getModifiers();
        Expect.isTrue(Modifier.isPrivate(m) && Modifier.isFinal(m),
            "PriceBook." + f.getName() + " should be private final");
    }
}
