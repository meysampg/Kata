import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.List;
import kata.*;

class DipKataTest {
    @Check(id = "place-returns-receipt")
    void placeReturnsReceipt() {
        SmtpClient.WIRE.clear();
        Expect.equal("placed for ann@x.io", Orders.place("ann@x.io"), "Orders.place");
    }

    @Check(id = "confirmation-goes-over-smtp")
    void confirmationGoesOverSmtp() {
        SmtpClient.WIRE.clear();
        Orders.place("ann@x.io");
        Orders.place("bob@x.io");
        Expect.equal(List.of("ann@x.io: Order confirmed", "bob@x.io: Order confirmed"),
            SmtpClient.WIRE, "what reached the SMTP client");
    }

    @Check(id = "port-interface", kind = Kind.DESIGN)
    void portInterface() {
        Class<?> port = Types.named("Notifier");
        Expect.isTrue(port.isInterface(), "Notifier should be an interface");
        Method m = Types.singleAbstractMethod(port);
        Expect.equal("notify", m.getName(), "the method name");
        Expect.equal(List.of(String.class, String.class), List.of(m.getParameterTypes()), "notify's parameters");
    }

    @Check(id = "service-does-not-know-smtp", kind = Kind.DESIGN)
    void serviceDoesNotKnowSmtp() {
        var service = Source.type("OrderService");
        Expect.none(service.mentions("SmtpClient"), "OrderService still refers to SmtpClient");
        Expect.none(service.news("SmtpNotifier"), "OrderService still builds its own notifier");
    }

    @Check(id = "service-takes-its-port", kind = Kind.DESIGN)
    void serviceTakesItsPort() {
        Class<?> notifier = Types.named("Notifier");
        Class<?> service = Types.named("OrderService");
        var field = Types.onlyFieldOfType(service, notifier);
        Expect.isTrue(java.lang.reflect.Modifier.isFinal(field.getModifiers()),
            "OrderService." + field.getName() + " should be final");
        Types.constructor(service, notifier);
    }

    @Check(id = "any-notifier-works", kind = Kind.DESIGN)
    void anyNotifierWorks() throws Throwable {
        SmtpClient.WIRE.clear();
        Class<?> notifier = Types.named("Notifier");
        List<List<Object>> calls = new ArrayList<>();
        Object spy = Types.implement(notifier, args -> { calls.add(List.of(args)); return null; });
        Object service = Types.create(Types.constructor(Types.named("OrderService"), notifier), spy);
        Object receipt = Types.call(Types.method(service.getClass(), "place", String.class), service, "cy@x.io");
        Expect.equal("placed for cy@x.io", receipt, "the receipt");
        Expect.equal(List.of(List.of("cy@x.io", "Order confirmed")), calls, "what the injected Notifier received");
        Expect.isTrue(SmtpClient.WIRE.isEmpty(), "the service still reached SMTP behind the Notifier's back");
    }
}
