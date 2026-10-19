import java.time.Clock;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

record Invoice(String id, String customer, LocalDate due) { }

// A process-wide mail gateway. Delivered mail lands in SENT.
final class MailGateway {
    static final MailGateway INSTANCE = new MailGateway();
    static final List<String> SENT = new ArrayList<>();

    private MailGateway() { }

    void send(String to, String body) {
        SENT.add(to + ": " + body);
    }
}

final class InvoiceStore implements InvoiceSource {
    public List<Invoice> all() {
        return List.of(
            new Invoice("A-1", "ana", LocalDate.parse("2020-01-01")),
            new Invoice("A-2", "bo", LocalDate.parse("2999-01-01")),
            new Invoice("A-3", "cy", LocalDate.parse("2020-06-01")));
    }
}

// Callers start here. Keep its signature and behaviour.
final class Reminders {
    private Reminders() { }

    // The composition root: the only place that chooses implementations.
    static InvoiceReminder create() {
        Mailer mailer = (to, body) -> MailGateway.INSTANCE.send(to, body);
        return new InvoiceReminder(
            new InvoiceStore(), mailer, Clock.systemDefaultZone());
    }
}
