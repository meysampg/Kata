import java.lang.reflect.Modifier;
import java.util.HashSet;
import java.util.List;
import java.util.concurrent.atomic.AtomicBoolean;
import kata.*;

class DoubleCheckedLockingKataTest {
    /** True when the thread is parked or blocked inside Config.get(). */
    static boolean waitsInGet(Thread t) {
        Thread.State s = t.getState();
        if (s != Thread.State.BLOCKED && s != Thread.State.WAITING) {
            return false;
        }
        for (StackTraceElement f : t.getStackTrace()) {
            if (f.getClassName().equals("Config")
                    && f.getMethodName().equals("get")) {
                return true;
            }
        }
        return false;
    }

    static void awaitOtherCallers() {
        long end = System.nanoTime() + 2_000_000_000L;
        while (System.nanoTime() < end) {
            long waiting = Thread.getAllStackTraces().keySet().stream()
                .filter(t -> t != Thread.currentThread())
                .filter(t -> t.getName().startsWith("kata-race"))
                .filter(DoubleCheckedLockingKataTest::waitsInGet)
                .count();
            if (waiting >= 7) {
                return;
            }
            Thread.yield();
        }
    }

    @Check(id = "one-instance-under-contention", timeoutMs = 5000, repeat = 5)
    void oneInstanceUnderContention() {
        Types.setStatic(Config.class, "instance", null);
        Config.CREATED.set(0);
        // The first builder waits until the other 7 callers are queued for
        // the lock inside get(), so every one of them takes the slow path.
        AtomicBoolean first = new AtomicBoolean(true);
        Config.onConstruct = () -> {
            if (first.getAndSet(false)) {
                awaitOtherCallers();
            }
        };
        List<Config> all = Stress.race(8, Config::get);
        Expect.equal(1, Config.CREATED.get(),
            "Config constructor calls for 8 simultaneous callers");
        Expect.equal(1, new HashSet<>(all).size(),
            "distinct Config objects handed out");
    }

    @Check(id = "mode-is-visible")
    void modeIsVisible() {
        Types.setStatic(Config.class, "instance", null);
        Config.onConstruct = () -> { };
        Expect.equal("prod", Config.get().mode(), "Config.get().mode()");
    }

    @Check(id = "fast-path-does-not-lock")
    void fastPathDoesNotLock() {
        Types.setStatic(Config.class, "instance", null);
        Config.onConstruct = () -> { };
        Config first = Config.get();
        try (var hold = Stress.holdMonitor(Config.class)) {
            Config again = Expect.completesWithin(300, Config::get,
                "Config.get() while another thread holds the class monitor");
            Expect.isTrue(again == first, "get() should return the same Config");
        }
    }

    @Check(id = "instance-is-volatile", kind = Kind.DESIGN)
    void instanceIsVolatile() {
        var field = Types.onlyStaticFieldOfType(Config.class, Config.class);
        Expect.isTrue(Modifier.isVolatile(field.getModifiers()),
            "Config." + field.getName() + " is read without a lock, so it "
            + "should be volatile");
    }

    @Check(id = "single-read-on-fast-path", kind = Kind.DESIGN)
    void singleReadOnFastPath() {
        var field = Types.onlyStaticFieldOfType(Config.class, Config.class);
        var reads = Source.type("Config").method("get")
            .fieldReads(field.getName()).stream()
            .filter(h -> !h.insideSynchronized()).toList();
        Expect.atMost(1, reads,
            "get() reads the field more than once outside the lock; "
            + "read it into a local");
    }
}
