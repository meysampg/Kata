import java.lang.reflect.Modifier;
import java.util.HashSet;
import java.util.List;
import kata.*;

class DoubleCheckedLockingKataTest {
    @Check(id = "one-instance-under-contention", timeoutMs = 5000, repeat = 10)
    void oneInstanceUnderContention() {
        Types.setStatic(Config.class, "instance", null);
        Config.CREATED.set(0);
        Config.onConstruct = () -> Stress.pause(20);
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
