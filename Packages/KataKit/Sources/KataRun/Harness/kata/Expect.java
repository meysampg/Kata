package kata;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Objects;
import java.util.concurrent.atomic.AtomicReference;

/** Assertions with messages written for the learner. */
public final class Expect {
    private Expect() {}

    @FunctionalInterface
    public interface ThrowingRunnable {
        void run() throws Throwable;
    }

    @FunctionalInterface
    public interface ThrowingSupplier<T> {
        T get() throws Throwable;
    }

    public static void equal(Object expected, Object actual, String what) {
        boolean same = expected != null && expected.getClass().isArray() && actual != null && actual.getClass().isArray()
                ? Arrays.deepEquals(new Object[] {expected}, new Object[] {actual})
                : Objects.equals(expected, actual);
        if (!same) {
            throw new CheckFailure(what + ": expected " + show(expected) + " but got " + show(actual));
        }
    }

    public static void isTrue(boolean condition, String message) {
        if (!condition) {
            throw new CheckFailure(message);
        }
    }

    public static void fail(String message) {
        throw new CheckFailure(message);
    }

    /** Passes when the action throws an instance of {@code type}; returns the exception. */
    public static <T extends Throwable> T raises(Class<T> type, ThrowingRunnable action, String what) {
        try {
            action.run();
        } catch (Throwable t) {
            if (type.isInstance(t)) {
                return type.cast(t);
            }
            throw new CheckFailure(what + " should raise " + type.getSimpleName() + " but raised "
                    + t.getClass().getSimpleName() + (t.getMessage() == null ? "" : ": " + t.getMessage()));
        }
        throw new CheckFailure(what + " should raise " + type.getSimpleName() + " but nothing was raised");
    }

    /** Fails with the position of the first hit when the list is not empty. */
    public static void none(List<Hit> hits, String message) {
        atMost(0, hits, message);
    }

    public static void atMost(int n, List<Hit> hits, String message) {
        if (hits.size() <= n) {
            return;
        }
        Hit first = hits.get(n);
        List<Hit> shown = hits.subList(n, Math.min(hits.size(), n + 3));
        boolean sameFile = shown.stream().allMatch(h -> h.file().equals(first.file()));
        List<String> where = new ArrayList<>();
        for (Hit h : shown) {
            where.add(sameFile ? String.valueOf(h.line()) : h.file() + ":" + h.line());
        }
        String more = hits.size() - n > 3 ? ", ..." : "";
        String prefix = sameFile ? first.file() + " line" + (shown.size() > 1 ? "s " : " ") : "";
        throw new CheckFailure(message + " (" + prefix + String.join(", ", where) + more + ")", first.file(),
                first.line());
    }

    /** Runs the supplier on another thread and fails if it does not finish in time. */
    public static <T> T completesWithin(long ms, ThrowingSupplier<T> supplier, String what) {
        AtomicReference<T> value = new AtomicReference<>();
        AtomicReference<Throwable> error = new AtomicReference<>();
        Thread t = new Thread(null, () -> {
            try {
                value.set(supplier.get());
            } catch (Throwable e) {
                error.set(e);
            }
        }, "kata-within", 0);
        t.setDaemon(true);
        t.start();
        try {
            t.join(ms);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new CheckFailure("interrupted while waiting for " + what);
        }
        if (t.isAlive()) {
            throw new CheckFailure(what + " did not finish within " + ms + " ms (is it blocked?)");
        }
        if (error.get() != null) {
            Throwable e = error.get();
            if (e instanceof RuntimeException r) {
                throw r;
            }
            if (e instanceof Error r) {
                throw r;
            }
            throw new CheckFailure(what + " raised " + e);
        }
        return value.get();
    }

    private static String show(Object o) {
        if (o instanceof String s) {
            return "\"" + s + "\"";
        }
        if (o instanceof Class<?> c) {
            return c.getSimpleName();
        }
        return String.valueOf(o);
    }
}
