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

final class InvoiceStore {
    List<Invoice> all() {
        return List.of(
            new Invoice("A-1", "ana", LocalDate.parse("2020-01-01")),
            new Invoice("A-2", "bo", LocalDate.parse("2999-01-01")),
            new Invoice("A-3", "cy", LocalDate.parse("2020-06-01")));
    }
}

// Builds its own collaborators and reads the system date.
final class InvoiceReminder {
    private final InvoiceStore store = new InvoiceStore();

    int remind() {
        LocalDate today = LocalDate.now();
        int count = 0;
        for (Invoice inv : store.all()) {
            if (inv.due().isBefore(today)) {
                MailGateway.INSTANCE.send(
                    inv.customer(), inv.id() + " overdue");
                count++;
            }
        }
        return count;
    }
}

// Callers start here. Keep its signature and behaviour.
final class Reminders {
    private Reminders() { }

    static InvoiceReminder create() {
        return new InvoiceReminder();
    }
}
