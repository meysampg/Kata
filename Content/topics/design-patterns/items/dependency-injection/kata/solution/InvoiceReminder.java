import java.time.Clock;
import java.time.LocalDate;
import java.util.List;
import java.util.Objects;

interface Mailer {
    void send(String to, String body);
}

interface InvoiceSource {
    List<Invoice> all();
}

final class InvoiceReminder {
    private final InvoiceSource source;
    private final Mailer mailer;
    private final Clock clock;

    InvoiceReminder(InvoiceSource source, Mailer mailer, Clock clock) {
        this.source = Objects.requireNonNull(source);
        this.mailer = Objects.requireNonNull(mailer);
        this.clock = Objects.requireNonNull(clock);
    }

    int remind() {
        LocalDate today = LocalDate.now(clock);
        int count = 0;
        for (Invoice inv : source.all()) {
            if (inv.due().isBefore(today)) {
                mailer.send(inv.customer(), inv.id() + " overdue");
                count++;
            }
        }
        return count;
    }
}
