import java.lang.reflect.Field;
import java.lang.reflect.Modifier;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.locks.ReentrantReadWriteLock;
import java.util.function.BooleanSupplier;
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
        Expect.equal(3, Expect.completesWithin(300,
            () -> book.price("apple"), "price(\"apple\") for a cached sku"),
            "price(\"apple\")");
        Expect.equal(0, loads.get(), "loader calls for a cached sku");
    }

    @Check(id = "miss-loads-and-caches", timeoutMs = 3000)
    void missLoadsAndCaches() {
        var loads = new AtomicInteger();
        var book = new PriceBook(sku -> 40 + loads.incrementAndGet());
        Expect.equal(41, Expect.completesWithin(300,
            () -> book.price("pear"), "price(\"pear\") for a missing sku"),
            "first price(\"pear\")");
        Expect.equal(41, Expect.completesWithin(300,
            () -> book.price("pear"), "second price(\"pear\")"),
            "second price(\"pear\")");
        Expect.equal(1, loads.get(), "loader calls for one sku");
    }

    /** True once every thread is parked inside WriteLock.lock(). */
    static boolean allWaitForWriteLock(List<Thread> threads) {
        for (Thread t : threads) {
            if (t.getState() != Thread.State.WAITING) {
                return false;
            }
            boolean inWriteLock = false;
            for (StackTraceElement f : t.getStackTrace()) {
                inWriteLock |= f.getClassName().endsWith("$WriteLock")
                    && f.getMethodName().equals("lock");
            }
            if (!inWriteLock) {
                return false;
            }
        }
        return true;
    }

    static void spinUntil(BooleanSupplier condition, long ms) {
        long end = System.nanoTime() + ms * 1_000_000L;
        while (!condition.getAsBoolean() && System.nanoTime() < end) {
            Thread.onSpinWait();
        }
    }

    @Check(id = "concurrent-misses-load-once", timeoutMs = 3000)
    void concurrentMissesLoadOnce() throws Throwable {
        var loads = new AtomicInteger();
        var book = new PriceBook(sku -> 40 + loads.incrementAndGet());
        var rw = lockOf(book);
        var got = new ConcurrentLinkedQueue<Integer>();
        var callers = new ArrayList<Thread>();
        // Hold the write lock so all 8 callers queue up for the read lock,
        // then downgrade: they all miss together, and every one of them
        // reaches the write lock before anyone may load.
        var downgraded = new CountDownLatch(1);
        var release = new CountDownLatch(1);
        var holder = new Thread(null, () -> {
            rw.writeLock().lock();
            try {
                for (int i = 0; i < 8; i++) {
                    Thread t = new Thread(null,
                        () -> got.add(book.price("plum")), "kata-caller", 0);
                    t.setDaemon(true);
                    callers.add(t);
                    t.start();
                }
                spinUntil(() -> rw.getQueueLength() == 8, 2000);
                rw.readLock().lock();
            } finally {
                rw.writeLock().unlock();
            }
            downgraded.countDown();
            try {
                release.await();
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            } finally {
                rw.readLock().unlock();
            }
        }, "kata-holder", 0);
        holder.setDaemon(true);
        holder.start();
        try {
            Expect.isTrue(downgraded.await(2, TimeUnit.SECONDS),
                "the test could not set up 8 waiting callers");
            spinUntil(() -> allWaitForWriteLock(callers), 1000);
        } finally {
            release.countDown();
        }
        long end = System.nanoTime() + 400_000_000L;
        for (Thread t : callers) {
            t.join(Math.max(1, (end - System.nanoTime()) / 1_000_000));
            Expect.isTrue(!t.isAlive(), "8 threads asking for the same "
                + "missing sku did not finish within 400 ms (is a thread "
                + "waiting for the write lock while it holds the read lock?)");
        }
        Expect.equal(1, loads.get(), "loader calls for 8 simultaneous misses");
        Expect.equal(8L, got.stream().filter(p -> p == 41).count(),
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
        var thrown = Expect.completesWithin(300, () -> {
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
        Expect.completesWithin(300, () -> {
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
        Expect.completesWithin(300, () -> book.price("lime"),
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
