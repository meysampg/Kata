import java.time.Clock;
import java.time.LocalDate;

// Ports: what the domain needs from the outside.
interface UserStore {
    boolean exists(String email);

    void add(String email);
}

interface Mailer {
    void send(String to, String body);
}

// The hexagon: rules only, no infrastructure.
final class Registration {
    private final UserStore store;
    private final Mailer mailer;
    private final Clock clock;

    Registration(UserStore store, Mailer mailer, Clock clock) {
        this.store = store;
        this.mailer = mailer;
        this.clock = clock;
    }

    String register(String email) {
        if (!email.contains("@")) return "invalid";
        if (store.exists(email)) return "duplicate";
        store.add(email);
        LocalDate trialEnd = LocalDate.now(clock).plusDays(14);
        mailer.send(email, "Welcome, trial ends " + trialEnd);
        return "registered";
    }
}
