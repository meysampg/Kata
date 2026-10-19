package kata;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.Callable;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.locks.Lock;

/** Deterministic concurrency helpers: start gates and held locks, never sleeps for correctness. */
public final class Stress {
    /** An {@link AutoCloseable} whose close() does not throw. */
    public interface Hold extends AutoCloseable {
        @Override
        void close();
    }

    private static final long JOIN_MS = 4000;

    private Stress() {}

    /**
     * Starts {@code threads} threads, releases them together through a gate, and returns their results
     * in thread order. Fails if any thread throws or does not finish in time.
     */
    public static <T> List<T> race(int threads, Callable<T> task) {
        CountDownLatch ready = new CountDownLatch(threads);
        CountDownLatch gate = new CountDownLatch(1);
        List<Thread> all = new ArrayList<>();
        Object[] results = new Object[threads];
        Throwable[] errors = new Throwable[threads];
        for (int i = 0; i < threads; i++) {
            int index = i;
            Thread t = new Thread(null, () -> {
                ready.countDown();
                try {
                    gate.await();
                    results[index] = task.call();
                } catch (Throwable e) {
                    errors[index] = e;
                }
            }, "kata-race-" + i, 0);
            t.setDaemon(true);
            all.add(t);
            t.start();
        }
        try {
            if (!ready.await(JOIN_MS, TimeUnit.MILLISECONDS)) {
                throw new CheckFailure("Could not start " + threads + " threads");
            }
            gate.countDown();
            long deadline = System.nanoTime() + TimeUnit.MILLISECONDS.toNanos(JOIN_MS);
            for (Thread t : all) {
                long left = TimeUnit.NANOSECONDS.toMillis(deadline - System.nanoTime());
                t.join(Math.max(1, left));
                if (t.isAlive()) {
                    throw new CheckFailure("Concurrent callers did not finish within " + JOIN_MS
                            + " ms (deadlock or endless wait?)");
                }
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new CheckFailure("interrupted");
        }
        for (Throwable e : errors) {
            if (e != null) {
                throw new CheckFailure("A concurrent caller threw " + e);
            }
        }
        List<T> out = new ArrayList<>();
        for (Object r : results) {
            @SuppressWarnings("unchecked")
            T value = (T) r;
            out.add(value);
        }
        return out;
    }

    /** Widens a race window. Limited to 50 ms: it must never be what makes a check pass. */
    public static void pause(long ms) {
        if (ms < 0 || ms > 50) {
            throw new IllegalArgumentException("Stress.pause is limited to 0..50 ms");
        }
        try {
            Thread.sleep(ms);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }

    /** Another thread owns the monitor of {@code monitor} until the result is closed. */
    public static Hold holdMonitor(Object monitor) {
        CountDownLatch held = new CountDownLatch(1);
        CountDownLatch release = new CountDownLatch(1);
        Thread t = new Thread(null, () -> {
            synchronized (monitor) {
                held.countDown();
                awaitQuietly(release);
            }
        }, "kata-monitor-holder", 0);
        return start(t, held, release);
    }

    /** Another thread holds {@code lock} until the result is closed. */
    public static Hold holdLock(Lock lock) {
        CountDownLatch held = new CountDownLatch(1);
        CountDownLatch release = new CountDownLatch(1);
        Thread t = new Thread(null, () -> {
            lock.lock();
            try {
                held.countDown();
                awaitQuietly(release);
            } finally {
                lock.unlock();
            }
        }, "kata-lock-holder", 0);
        return start(t, held, release);
    }

    private static Hold start(Thread t, CountDownLatch held, CountDownLatch release) {
        t.setDaemon(true);
        t.start();
        try {
            if (!held.await(JOIN_MS, TimeUnit.MILLISECONDS)) {
                throw new CheckFailure("Could not take the lock for the test");
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
        return () -> {
            release.countDown();
            try {
                t.join(JOIN_MS);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        };
    }

    private static void awaitQuietly(CountDownLatch latch) {
        try {
            latch.await();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
}
