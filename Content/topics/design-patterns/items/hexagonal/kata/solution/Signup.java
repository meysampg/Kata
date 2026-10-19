import java.time.Clock;
import java.util.ArrayList;
import java.util.List;

// The "SMTP server": delivered mail lands in SmtpClient.OUTBOX.
final class SmtpClient {
    static final List<String> OUTBOX = new ArrayList<>();

    private SmtpClient() { }

    static void send(String to, String body) {
        OUTBOX.add(to + ": " + body);
    }
}

// Callers start here. Keep its signature and behaviour.
final class Wiring {
    private Wiring() { }

    static Registration create() {
        return new Registration(
            new MemoryUserStore(), new SmtpMailer(), Clock.systemDefaultZone());
    }
}
