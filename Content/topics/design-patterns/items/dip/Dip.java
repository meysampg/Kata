import java.util.ArrayList;
import java.util.List;

// [[before
final class SmtpClient {
    void send(String to, String body) { System.out.println("SMTP " + to); }
}

final class OrderServiceBefore {
    private final SmtpClient smtp = new SmtpClient();   // hard-wired detail

    void place(String customer) {
        smtp.send(customer, "Order confirmed");
    }
}
// ]]

// [[abstraction
interface Notifier {                         // owned by the high-level policy
    void notify(String customer, String message);
}
// ]]

// [[highlevel
final class OrderService {
    private final Notifier notifier;

    OrderService(Notifier notifier) { this.notifier = notifier; }

    void place(String customer) {
        notifier.notify(customer, "Order confirmed");
    }
}
// ]]

// [[details
final class SmtpNotifier implements Notifier {
    public void notify(String customer, String message) {
        System.out.println("SMTP " + customer + ": " + message);
    }
}

final class RecordingNotifier implements Notifier {
    final List<String> sent = new ArrayList<>();
    public void notify(String customer, String message) {
        sent.add(customer + "/" + message);
    }
}
// ]]

class Main {
    public static void main(String[] args) {
        new OrderServiceBefore().place("ada");
        // [[wiring
        new OrderService(new SmtpNotifier()).place("ada");

        var fake = new RecordingNotifier();
        new OrderService(fake).place("grace");
        // ]]
        System.out.println("test double saw " + fake.sent);
    }
}
