import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.ObjectInputStream;
import java.io.ObjectOutputStream;
import java.lang.reflect.Constructor;
import java.lang.reflect.Field;
import java.lang.reflect.Modifier;
import java.util.List;
import kata.*;

class SingletonKataTest {
    // Must stay the first check: it needs AppConfig to be untouched so far.
    @Check(id = "one-instance-under-contention", timeoutMs = 5000)
    void oneInstanceUnderContention() {
        Probe.CREATED.set(0);
        Probe.onConstruct = () -> Stress.pause(40);
        List<AppConfig> seen = Stress.race(8, AppConfig::get);
        Probe.onConstruct = () -> { };
        Expect.equal(1, Probe.CREATED.get(),
            "AppConfig instances constructed by 8 threads calling get() together");
        for (AppConfig c : seen) {
            Expect.isTrue(c == seen.get(0), "the 8 threads were handed different instances");
        }
    }

    @Check(id = "same-instance-every-call")
    void sameInstanceEveryCall() {
        Expect.isTrue(AppConfig.get() == AppConfig.get(), "get() should always return the same object");
    }

    @Check(id = "config-still-works")
    void configStillWorks() {
        Expect.equal("eu-west-1", AppConfig.get().region(), "region()");
    }

    @Check(id = "reflection-cannot-make-a-second", kind = Kind.BEHAVIOUR)
    void reflectionCannotMakeASecond() throws Exception {
        AppConfig shared = AppConfig.get();
        for (Constructor<?> c : AppConfig.class.getDeclaredConstructors()) {
            c.setAccessible(true);
            Object[] args = new Object[c.getParameterCount()];
            Class<?>[] types = c.getParameterTypes();
            for (int i = 0; i < args.length; i++) {
                if (types[i] == int.class) args[i] = 0;
                else if (types[i] == String.class) args[i] = "X";
            }
            try {
                Object other = c.newInstance(args);
                Expect.isTrue(other == shared,
                    "Reflection built a second AppConfig through its private constructor");
            } catch (java.lang.reflect.InvocationTargetException | IllegalArgumentException
                     | InstantiationException e) {
                // refused: good
            }
        }
    }

    @Check(id = "serialization-keeps-identity")
    void serializationKeepsIdentity() throws Exception {
        AppConfig shared = AppConfig.get();
        Expect.isTrue(shared instanceof java.io.Serializable, "AppConfig should stay Serializable");
        ByteArrayOutputStream bytes = new ByteArrayOutputStream();
        try (ObjectOutputStream out = new ObjectOutputStream(bytes)) {
            out.writeObject(shared);
        }
        Object back;
        try (ObjectInputStream in = new ObjectInputStream(new ByteArrayInputStream(bytes.toByteArray())) {
            @Override
            protected Class<?> resolveClass(java.io.ObjectStreamClass d) throws java.io.IOException,
                    ClassNotFoundException {
                return Class.forName(d.getName(), false, AppConfig.class.getClassLoader());
            }
        }) {
            back = in.readObject();
        }
        Expect.isTrue(back == shared,
            "Deserializing AppConfig produced a second instance");
    }

    @Check(id = "shared-field-is-safe", kind = Kind.DESIGN)
    void sharedFieldIsSafe() {
        for (Field f : AppConfig.class.getDeclaredFields()) {
            if (f.getType() != AppConfig.class || !Modifier.isStatic(f.getModifiers())) continue;
            int m = f.getModifiers();
            Expect.isTrue(Modifier.isFinal(m) || Modifier.isVolatile(m),
                "AppConfig." + f.getName() + " is a lazily written static that is neither final nor volatile");
        }
    }

    @Check(id = "no-open-constructor", kind = Kind.DESIGN)
    void noOpenConstructor() {
        for (Constructor<?> c : AppConfig.class.getDeclaredConstructors()) {
            Expect.isTrue(Modifier.isPrivate(c.getModifiers()),
                "AppConfig's constructor should be private");
        }
    }

    @Check(id = "get-is-still-static", kind = Kind.DESIGN)
    void getIsStillStatic() {
        Expect.isTrue(Modifier.isStatic(Types.staticMethod(AppConfig.class, "get").getModifiers()),
            "AppConfig.get() should be static");
    }
}
