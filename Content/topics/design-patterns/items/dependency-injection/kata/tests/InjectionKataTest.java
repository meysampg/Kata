import java.lang.reflect.Field;
import java.lang.reflect.Modifier;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import kata.*;

class InjectionKataTest {
    static Clock at(String date) {
        return Clock.fixed(Instant.parse(date + "T00:00:00Z"), ZoneOffset.UTC);
    }

    /** Builds an InvoiceReminder from fakes; returns {reminder, mails}. */
    static Object[] build(List<Invoice> invoices, Clock clock) throws Throwable {
        Class<?> source = Types.named("InvoiceSource");
        Class<?> mailer = Types.named("Mailer");
        List<String> mails = new ArrayList<>();
        Object fakeSource = Types.implement(source, a -> invoices);
        Object fakeMailer = Types.implement(mailer, a -> mails.add(a[0] + ": " + a[1]));
        Object reminder = Types.create(
            Types.constructor(Types.named("InvoiceReminder"), source, mailer, Clock.class),
            fakeSource, fakeMailer, clock);
        return new Object[] {reminder, mails};
    }

    @Check(id = "overdue-are-reminded")
    void overdueAreReminded() {
        MailGateway.SENT.clear();
        Expect.equal(2, Reminders.create().remind(), "reminders sent");
        Expect.equal(List.of("ana: A-1 overdue", "cy: A-3 overdue"), MailGateway.SENT,
            "mails delivered");
    }

    @Check(id = "later-runs-add-up")
    void laterRunsAddUp() {
        MailGateway.SENT.clear();
        var job = Reminders.create();
        job.remind();
        job.remind();
        Expect.equal(4, MailGateway.SENT.size(), "mails after two runs");
    }

    @Check(id = "collaborators-are-injected", kind = Kind.DESIGN)
    void collaboratorsAreInjected() {
        Class<?> reminder = Types.named("InvoiceReminder");
        Class<?> source = Types.named("InvoiceSource");
        Class<?> mailer = Types.named("Mailer");
        Expect.isTrue(source.isInterface() && mailer.isInterface(),
            "InvoiceSource and Mailer should be interfaces");
        Types.constructor(reminder, source, mailer, Clock.class);
        for (Class<?> type : List.of(source, mailer, Clock.class)) {
            Field f = Types.onlyFieldOfType(reminder, type);
            Expect.isTrue(Modifier.isPrivate(f.getModifiers()) && Modifier.isFinal(f.getModifiers()),
                "InvoiceReminder." + f.getName() + " should be private final");
        }
    }

    @Check(id = "no-hard-wiring", kind = Kind.DESIGN)
    void noHardWiring() {
        var reminder = Source.type("InvoiceReminder");
        Expect.none(reminder.news("InvoiceStore"), "InvoiceReminder still creates its own store");
        Expect.none(reminder.mentions("MailGateway"), "InvoiceReminder still reaches a static singleton");
        Expect.none(reminder.mentions("INSTANCE"), "InvoiceReminder still reaches a static singleton");
        Expect.none(reminder.mentions("InvoiceStore"), "InvoiceReminder depends on a concrete store");
    }

    @Check(id = "clock-is-injected", kind = Kind.DESIGN)
    void clockIsInjected() throws Throwable {
        var invoices = List.of(
            new Invoice("X-1", "dee", LocalDate.parse("2026-03-10")),
            new Invoice("X-2", "eli", LocalDate.parse("2026-03-09")));
        Object[] early = build(invoices, at("2026-03-10"));
        var remind = Types.method(early[0].getClass(), "remind");
        Expect.equal(1, Types.call(remind, early[0]), "overdue on 2026-03-10");
        Object[] late = build(invoices, at("2026-04-01"));
        Expect.equal(2, Types.call(remind, late[0]), "overdue on 2026-04-01");
        Expect.equal(List.of("dee: X-1 overdue", "eli: X-2 overdue"), late[1],
            "mails sent through the injected Mailer (not a static gateway)");
    }

    @Check(id = "missing-collaborator-fails-early", kind = Kind.DESIGN)
    void missingCollaboratorFailsEarly() {
        Class<?> source = Types.named("InvoiceSource");
        Class<?> mailer = Types.named("Mailer");
        var ctor = Types.constructor(Types.named("InvoiceReminder"), source, mailer, Clock.class);
        Object aSource = Types.implement(source, a -> List.of());
        Object aMailer = Types.implement(mailer, a -> null);
        Clock aClock = Clock.systemUTC();
        Expect.raises(NullPointerException.class, () -> Types.create(ctor, null, aMailer, aClock),
            "constructing an InvoiceReminder with a null InvoiceSource");
        Expect.raises(NullPointerException.class, () -> Types.create(ctor, aSource, null, aClock),
            "constructing an InvoiceReminder with a null Mailer");
        Expect.raises(NullPointerException.class, () -> Types.create(ctor, aSource, aMailer, null),
            "constructing an InvoiceReminder with a null Clock");
    }
}
