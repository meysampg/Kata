import java.util.Map;
import java.util.Objects;
import java.util.concurrent.ConcurrentHashMap;

// A typed registry of services. Each locator is independent.
final class ServiceLocator {
    private final Map<Class<?>, Object> services = new ConcurrentHashMap<>();

    <T> void register(Class<T> type, T service) {
        Objects.requireNonNull(type);
        Objects.requireNonNull(service);
        if (services.putIfAbsent(type, service) != null) {
            throw new IllegalStateException(
                "already registered: " + type.getSimpleName());
        }
    }

    <T> T get(Class<T> type) {
        Object service = services.get(type);
        if (service == null) {
            throw new IllegalStateException(
                "no service registered for " + type.getSimpleName());
        }
        return type.cast(service);
    }
}
