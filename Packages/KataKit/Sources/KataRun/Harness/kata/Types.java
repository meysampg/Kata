package kata;

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

    public static Method singleAbstractMethod(Class<?> type) {
        List<Method> abstracts = new ArrayList<>();
        for (Method m : type.getMethods()) {
            if (Modifier.isAbstract(m.getModifiers()) && !isObjectMethod(m)) {
                abstracts.add(m);
            }
        }
        if (abstracts.size() != 1) {
            throw new CheckFailure(type.getSimpleName() + " should have exactly one abstract method but has "
                    + abstracts.size());
        }
        return abstracts.get(0);
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
            if (method.isDefault()) {
                return InvocationHandler.invokeDefault(proxy, method, args);
            }
            return handler.apply(args == null ? new Object[0] : args);
        };
        return Proxy.newProxyInstance(type.getClassLoader(), new Class<?>[] {type}, h);
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
