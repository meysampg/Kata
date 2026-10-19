import java.time.LocalDate;
import java.util.HashSet;
import java.util.Set;

// The "SMTP server": delivered mail lands in SmtpClient.OUTBOX.
final class SmtpClient {
    static final java.util.List<String> OUTBOX = new java.util.ArrayList<>();

    private SmtpClient() { }

    static void send(String to, String body) {
        OUTBOX.add(to + ": " + body);
    }
}

// The domain talks to SMTP and to the system clock directly.
final class Registration {
    private final Set<String> emails = new HashSet<>();

    String register(String email) {
        if (!email.contains("@")) return "invalid";
        if (!emails.add(email)) return "duplicate";
        LocalDate trialEnd = LocalDate.now().plusDays(14);
        SmtpClient.send(email, "Welcome, trial ends " + trialEnd);
        return "registered";
    }
}

// Callers start here. Keep its signature and behaviour.
final class Wiring {
    private Wiring() { }

    static Registration create() {
        return new Registration();
    }
}
