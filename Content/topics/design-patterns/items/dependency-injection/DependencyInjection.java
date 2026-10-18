import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;

record Invoice(String id, String customer, LocalDate due) {}

// [[contract
interface Mailer {
    void send(String to, String body);
}
// ]]

// [[consumer
final class InvoiceReminder {
    private final Clock clock;
    private final Mailer mailer;

    InvoiceReminder(Clock clock, Mailer mailer) {
        this.clock = Objects.requireNonNull(clock);
        this.mailer = Objects.requireNonNull(mailer);
    }

    int remind(List<Invoice> invoices) {
        LocalDate today = LocalDate.now(clock);
        int count = 0;
        for (Invoice inv : invoices) {
            if (inv.due().isBefore(today)) {
                mailer.send(inv.customer(), inv.id() + " overdue");
                count++;
            }
        }
        return count;
    }
}
// ]]

class Main {
    static Clock at(String isoDate) {
        Instant start = Instant.parse(isoDate + "T00:00:00Z");
        return Clock.fixed(start, ZoneOffset.UTC);
    }

    public static void main(String[] args) {
        var invoices = List.of(
            new Invoice("A-1", "ana", LocalDate.parse("2026-03-01")),
            new Invoice("A-2", "bo", LocalDate.parse("2026-03-20")));
        // [[root
        Mailer console = (to, body) -> System.out.println(to + ": " + body);
        var job = new InvoiceReminder(at("2026-03-10"), console);
        System.out.println("sent " + job.remind(invoices));
        // ]]
        // [[test
        var outbox = new ArrayList<String>();
        var later = new InvoiceReminder(at("2026-04-01"),
                (to, body) -> outbox.add(to));
        System.out.println("sent " + later.remind(invoices) + " " + outbox);
        // ]]
    }
}
