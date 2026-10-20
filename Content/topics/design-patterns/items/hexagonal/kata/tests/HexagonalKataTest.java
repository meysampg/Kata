import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.Function;
import kata.*;

class HexagonalKataTest {
    @Check(id = "invalid-email")
    void invalidEmail() {
        SmtpClient.OUTBOX.clear();
        Expect.equal("invalid", Wiring.create().register("nobody"), "an email without @");
        Expect.equal(0, SmtpClient.OUTBOX.size(), "mails sent for an invalid email");
    }

    @Check(id = "duplicate-email")
    void duplicateEmail() {
        SmtpClient.OUTBOX.clear();
        var app = Wiring.create();
        Expect.equal("registered", app.register("ana@x.org"), "first registration");
        Expect.equal("duplicate", app.register("ana@x.org"), "second registration");
        Expect.equal(1, SmtpClient.OUTBOX.size(), "welcome mails sent");
    }

    @Check(id = "welcome-mail")
    void welcomeMail() {
        SmtpClient.OUTBOX.clear();
        Wiring.create().register("ana@x.org");
        Expect.equal(1, SmtpClient.OUTBOX.size(), "welcome mails sent");
        Expect.isTrue(SmtpClient.OUTBOX.get(0).startsWith("ana@x.org: Welcome, trial ends "),
            "the mail should be addressed to ana@x.org, got " + SmtpClient.OUTBOX.get(0));
    }

    @Check(id = "ports-exist", kind = Kind.DESIGN)
    void portsExist() {
        Class<?> store = Types.named("UserStore");
        Class<?> mailer = Types.named("Mailer");
        Expect.isTrue(store.isInterface() && mailer.isInterface(),
            "UserStore and Mailer should be interfaces");
        Types.method(store, "exists", String.class);
        Types.method(store, "add", String.class);
        Types.method(mailer, "send", String.class, String.class);
    }

    @Check(id = "domain-takes-ports", kind = Kind.DESIGN)
    void domainTakesPorts() {
        Types.constructor(Types.named("Registration"),
            Types.named("UserStore"), Types.named("Mailer"), Clock.class);
    }

    @Check(id = "domain-has-no-infrastructure", kind = Kind.DESIGN)
    void domainHasNoInfrastructure() {
        var domain = Source.type("Registration");
        Expect.none(domain.mentions("SmtpClient"), "Registration still calls SMTP directly");
        Expect.none(domain.mentions("OUTBOX"), "Registration still touches the outbox");
        Expect.none(domain.news("HashSet"), "Registration still keeps the storage itself");
        Expect.none(domain.calls("currentTimeMillis"), "Registration reads the system clock");
        Expect.none(domain.calls("now").stream().filter(h -> h.args().isEmpty()).toList(),
            "Registration reads the system clock; pass the injected Clock to now(...)");
    }

    @Check(id = "domain-uses-the-injected-clock", kind = Kind.DESIGN)
    void domainUsesTheInjectedClock() throws Throwable {
        Set<String> known = new HashSet<>();
        List<String> mails = new ArrayList<>();
        Clock clock = Clock.fixed(Instant.parse("2001-03-10T00:00:00Z"), ZoneOffset.UTC);
        Object app = registration(Map.of(
            "exists", a -> known.contains((String) a[0]),
            "add", a -> known.add((String) a[0])), mails, clock);
        var register = Types.method(app.getClass(), "register", String.class);
        Expect.equal("registered", Types.call(register, app, "ana@x.org"), "register");
        Expect.equal(Set.of("ana@x.org"), known, "what Registration added to the UserStore port");
        Expect.equal(List.of("ana@x.org: Welcome, trial ends 2001-03-24"), mails,
            "mails produced with the fixed clock");
        Expect.equal("duplicate", Types.call(register, app, "ana@x.org"), "register again");
        Expect.equal(1, mails.size(), "mails after a duplicate");
    }

    @Check(id = "store-decides-duplicates", kind = Kind.DESIGN)
    void storeDecidesDuplicates() throws Throwable {
        List<String> mails = new ArrayList<>();
        Object app = registration(Map.of("exists", a -> true, "add", a -> null),
            mails, Clock.systemUTC());
        var register = Types.method(app.getClass(), "register", String.class);
        Expect.equal("duplicate", Types.call(register, app, "bo@x.org"),
            "an email the store already knows");
        Expect.equal(0, mails.size(), "mails for a known email");
    }

    /** A Registration over a stub UserStore and a Mailer that records "to: body". */
    static Object registration(Map<String, Function<Object[], Object>> store, List<String> mails,
            Clock clock) throws Throwable {
        Class<?> storePort = Types.named("UserStore");
        Class<?> mailerPort = Types.named("Mailer");
        Object fakeStore = Types.implement(storePort, store);
        Object fakeMailer = Types.implement(mailerPort, a -> mails.add(a[0] + ": " + a[1]));
        return Types.create(
            Types.constructor(Types.named("Registration"), storePort, mailerPort, Clock.class),
            fakeStore, fakeMailer, clock);
    }
}
