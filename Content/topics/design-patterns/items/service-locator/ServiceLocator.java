import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

// [[locator
final class Locator {
    private static final Map<Class<?>, Object> SERVICES =
            new ConcurrentHashMap<>();

    static <T> void register(Class<T> type, T service) {
        SERVICES.put(type, service);
    }

    static <T> T get(Class<T> type) {
        Object service = SERVICES.get(type);
        if (service == null) {
            throw new IllegalStateException(
                "no service registered for " + type.getSimpleName());
        }
        return type.cast(service);
    }

    static void clear() { SERVICES.clear(); }
}
// ]]

interface Mailer {
    void send(String to, String body);
}

// [[consumer
final class SignupService {
    // Nothing in the constructor or fields reveals the Mailer need.
    void signUp(String email) {
        Mailer mailer = Locator.get(Mailer.class);
        mailer.send(email, "Welcome");
    }
}
// ]]

class Main {
    public static void main(String[] args) {
        var service = new SignupService();
        // [[registration
        Locator.register(Mailer.class,
                (to, body) -> System.out.println(body + ", " + to));
        // ]]
        service.signUp("ana");
        // [[failure
        Locator.clear();
        try {
            service.signUp("bo");
        } catch (IllegalStateException e) {
            System.out.println("runtime: " + e.getMessage());
        }
        // ]]
    }
}
