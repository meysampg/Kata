package kata;

import java.lang.invoke.MethodHandles;
import java.lang.reflect.Constructor;
import java.lang.reflect.Field;
import java.lang.reflect.InvocationHandler;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.lang.reflect.Proxy;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

/** Reflection helpers that fail with messages a learner can act on. */
public final class Types {
    private Types() {}

    /** A type declared in the learner's files (simple name). */
    public static Class<?> named(String name) {
        Class<?> c = Context.findUserType(name);
        if (c == null) {
            throw new CheckFailure("No type named " + name + " in your files");
        }
        return c;
    }

    /**
     * The one abstract method the type declares or inherits, of any visibility (so a
     * {@code protected abstract} method of a class counts). Object methods are ignored, and a method a
     * subclass or sub-interface implements is no longer abstract.
     */
    public static Method singleAbstractMethod(Class<?> type) {
        java.util.Map<String, Method> bySignature = new java.util.LinkedHashMap<>();
        java.util.ArrayDeque<Class<?>> queue = new java.util.ArrayDeque<>();
        java.util.Set<Class<?>> seen = new java.util.HashSet<>();
        queue.add(type);
        while (!queue.isEmpty()) {
            Class<?> c = queue.poll();
            if (c == Object.class || !seen.add(c)) {
                continue;
            }
            for (Method m : c.getDeclaredMethods()) {
                if (!m.isSynthetic() && !m.isBridge() && !Modifier.isStatic(m.getModifiers())
                        && !Modifier.isPrivate(m.getModifiers())) {
                    bySignature.putIfAbsent(m.getName() + Arrays.toString(m.getParameterTypes()), m);
                }
            }
            if (c.getSuperclass() != null) {
                queue.add(c.getSuperclass());
            }
            queue.addAll(Arrays.asList(c.getInterfaces()));
        }
        List<Method> abstracts = new ArrayList<>();
        for (Method m : bySignature.values()) {
            if (Modifier.isAbstract(m.getModifiers()) && !isObjectMethod(m)) {
                abstracts.add(m);
            }
        }
        if (abstracts.size() != 1) {
            throw new CheckFailure(type.getSimpleName() + " should have exactly one abstract method but has "
                    + abstracts.size());
        }
        Method m = abstracts.get(0);
        m.setAccessible(true);
        return m;
    }

    /** The only instance field whose declared type is {@code type}. */
    public static Field onlyFieldOfType(Class<?> owner, Class<?> type) {
        return only(owner, type, false);
    }

    /** The only static field whose declared type is {@code type}. */
    public static Field onlyStaticFieldOfType(Class<?> owner, Class<?> type) {
        return only(owner, type, true);
    }

    /** Every declared field (static or not) of exactly this type. */
    public static List<Field> fieldsOfType(Class<?> owner, Class<?> type) {
        List<Field> out = new ArrayList<>();
        for (Field f : owner.getDeclaredFields()) {
            if (!f.isSynthetic() && f.getType() == type) {
                f.setAccessible(true);
                out.add(f);
            }
        }
        return out;
    }

    public static void setStatic(Class<?> owner, String field, Object value) {
        try {
            Field f = owner.getDeclaredField(field);
            f.setAccessible(true);
            f.set(null, value);
        } catch (NoSuchFieldException e) {
            throw new CheckFailure(owner.getSimpleName() + " needs a static field named " + field);
        } catch (IllegalAccessException | RuntimeException e) {
            throw new CheckFailure("Cannot set " + owner.getSimpleName() + "." + field + ": " + e);
        }
    }

    public static Object getStatic(Class<?> owner, String field) {
        try {
            Field f = owner.getDeclaredField(field);
            f.setAccessible(true);
            return f.get(null);
        } catch (NoSuchFieldException e) {
            throw new CheckFailure(owner.getSimpleName() + " needs a static field named " + field);
        } catch (IllegalAccessException e) {
            throw new CheckFailure("Cannot read " + owner.getSimpleName() + "." + field + ": " + e);
        }
    }

    public static Constructor<?> constructor(Class<?> owner, Class<?>... params) {
        try {
            Constructor<?> c = owner.getDeclaredConstructor(params);
            c.setAccessible(true);
            return c;
        } catch (NoSuchMethodException e) {
            throw new CheckFailure(owner.getSimpleName() + " needs a constructor " + owner.getSimpleName() + "("
                    + names(params) + ")");
        }
    }

    public static Method method(Class<?> owner, String name, Class<?>... params) {
        Method m = find(owner, name, params);
        if (m == null) {
            throw new CheckFailure(owner.getSimpleName() + " needs a method " + name + "(" + names(params) + ")");
        }
        return m;
    }

    public static Method staticMethod(Class<?> owner, String name, Class<?>... params) {
        Method m = find(owner, name, params);
        if (m == null || !Modifier.isStatic(m.getModifiers())) {
            throw new CheckFailure(owner.getSimpleName() + " needs a static method " + name + "(" + names(params)
                    + ")");
        }
        return m;
    }

    /** Invokes a method and rethrows what it threw, not the reflection wrapper. */
    public static Object call(Method method, Object target, Object... args) throws Throwable {
        try {
            method.setAccessible(true);
            return method.invoke(target, args);
        } catch (InvocationTargetException e) {
            throw e.getCause();
        }
    }

    public static Object create(Constructor<?> constructor, Object... args) throws Throwable {
        try {
            constructor.setAccessible(true);
            return constructor.newInstance(args);
        } catch (InvocationTargetException e) {
            throw e.getCause();
        }
    }

    /**
     * An instance of the interface whose abstract methods all call {@code handler}. Object methods
     * and default methods behave normally.
     */
    public static Object implement(Class<?> type, Function<Object[], Object> handler) {
        return proxy(type, (method, args) -> handler.apply(args));
    }

    /**
     * An instance of the interface whose abstract methods dispatch by method name to {@code stubs}.
     * An abstract method without a stub throws {@link UnsupportedOperationException}. Object methods and
     * default methods behave normally; the interface may be package-private.
     */
    public static Object implement(Class<?> type, Map<String, Function<Object[], Object>> stubs) {
        return proxy(type, (method, args) -> {
            Function<Object[], Object> stub = stubs.get(method.getName());
            if (stub == null) {
                throw new UnsupportedOperationException("no stub for " + type.getSimpleName() + "."
                        + method.getName() + "()");
            }
            return stub.apply(args);
        });
    }

    private interface Dispatch {
        Object call(Method method, Object[] args) throws Throwable;
    }

    private static Object proxy(Class<?> type, Dispatch dispatch) {
        if (!type.isInterface()) {
            throw new CheckFailure(type.getSimpleName() + " should be an interface");
        }
        InvocationHandler h = (proxy, method, args) -> {
            if (method.getDeclaringClass() == Object.class) {
                return switch (method.getName()) {
                    case "equals" -> proxy == args[0];
                    case "hashCode" -> System.identityHashCode(proxy);
                    default -> type.getSimpleName() + "@kata";
                };
            }
            Object[] actual = args == null ? new Object[0] : args;
            if (method.isDefault()) {
                return invokeDefault(proxy, method, actual);
            }
            return dispatch.call(method, actual);
        };
        return Proxy.newProxyInstance(type.getClassLoader(), new Class<?>[] {type}, h);
    }

    /** Runs a default method from a lookup on its own interface, so package-private interfaces work. */
    private static Object invokeDefault(Object proxy, Method method, Object[] args) throws Throwable {
        Class<?> owner = method.getDeclaringClass();
        MethodHandles.Lookup lookup = MethodHandles.privateLookupIn(owner, MethodHandles.lookup());
        return lookup.unreflectSpecial(method, owner).bindTo(proxy).invokeWithArguments(args);
    }

    private static Field only(Class<?> owner, Class<?> type, boolean wantStatic) {
        List<Field> found = new ArrayList<>();
        for (Field f : fieldsOfType(owner, type)) {
            if (Modifier.isStatic(f.getModifiers()) == wantStatic) {
                found.add(f);
            }
        }
        if (found.size() != 1) {
            throw new CheckFailure(owner.getSimpleName() + " should have exactly one " + (wantStatic ? "static " : "")
                    + "field of type " + type.getSimpleName() + " but has " + found.size());
        }
        return found.get(0);
    }

    private static Method find(Class<?> owner, String name, Class<?>[] params) {
        for (Class<?> c = owner; c != null; c = c.getSuperclass()) {
            try {
                Method m = c.getDeclaredMethod(name, params);
                m.setAccessible(true);
                return m;
            } catch (NoSuchMethodException e) {
                // keep looking up the hierarchy
            }
        }
        try {
            return owner.getMethod(name, params);
        } catch (NoSuchMethodException e) {
            return null;
        }
    }

    private static boolean isObjectMethod(Method m) {
        try {
            Object.class.getMethod(m.getName(), m.getParameterTypes());
            return true;
        } catch (NoSuchMethodException e) {
            return false;
        }
    }

    private static String names(Class<?>[] params) {
        return Arrays.stream(params).map(Class::getSimpleName).collect(Collectors.joining(", "));
    }
}
