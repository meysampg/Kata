import java.util.ArrayList;
import java.util.List;

// Stands in for a real mail library: "sending" appends to WIRE.
final class SmtpClient {
    static final List<String> WIRE = new ArrayList<>();

    void send(String to, String body) { WIRE.add(to + ": " + body); }
}

// The policy class is welded to one delivery mechanism.
final class OrderService {
    private final SmtpClient smtp = new SmtpClient();

    String place(String customer) {
        smtp.send(customer, "Order confirmed");
        return "placed for " + customer;
    }
}

// Callers use this entry point. Keep its signature and behaviour.
final class Orders {
    private Orders() { }

    static String place(String customer) {
        return new OrderService().place(customer);
    }
}
