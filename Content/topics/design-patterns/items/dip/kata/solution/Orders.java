import java.util.ArrayList;
import java.util.List;

final class SmtpClient {
    static final List<String> WIRE = new ArrayList<>();

    void send(String to, String body) { WIRE.add(to + ": " + body); }
}

interface Notifier {
    void notify(String customer, String message);
}

final class SmtpNotifier implements Notifier {
    private final SmtpClient smtp;

    SmtpNotifier(SmtpClient smtp) { this.smtp = smtp; }

    public void notify(String customer, String message) {
        smtp.send(customer, message);
    }
}

final class OrderService {
    private final Notifier notifier;

    OrderService(Notifier notifier) { this.notifier = notifier; }

    String place(String customer) {
        notifier.notify(customer, "Order confirmed");
        return "placed for " + customer;
    }
}

final class Orders {
    private Orders() { }

    static String place(String customer) {
        return new OrderService(new SmtpNotifier(new SmtpClient()))
            .place(customer);
    }
}
