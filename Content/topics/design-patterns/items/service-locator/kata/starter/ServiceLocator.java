// A typed registry of services. Each locator is independent.
final class ServiceLocator {
    <T> void register(Class<T> type, T service) {
        throw new UnsupportedOperationException("TODO");
    }

    <T> T get(Class<T> type) {
        throw new UnsupportedOperationException("TODO");
    }
}
