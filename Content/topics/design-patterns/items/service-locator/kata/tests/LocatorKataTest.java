import java.lang.reflect.Modifier;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;
import kata.*;

class LocatorKataTest {
    @Check(id = "register-and-get")
    void registerAndGet() {
        var locator = new ServiceLocator();
        Mailer mailer = (to, body) -> { };
        locator.register(Mailer.class, mailer);
        locator.register(String.class, "hello");
        Expect.isTrue(locator.get(Mailer.class) == mailer, "get should return the registered instance");
        Expect.equal("hello", locator.get(String.class), "a second type");
    }

    @Check(id = "missing-fails-fast")
    void missingFailsFast() {
        var locator = new ServiceLocator();
        var e = Expect.raises(IllegalStateException.class, () -> locator.get(Mailer.class),
            "get for an unregistered type");
        Expect.equal("no service registered for Mailer", e.getMessage(), "the message");
    }

    @Check(id = "duplicate-is-rejected")
    void duplicateIsRejected() {
        var locator = new ServiceLocator();
        Mailer first = (to, body) -> { };
        locator.register(Mailer.class, first);
        var e = Expect.raises(IllegalStateException.class,
            () -> locator.register(Mailer.class, (to, body) -> { }), "registering a type twice");
        Expect.equal("already registered: Mailer", e.getMessage(), "the message");
        Expect.isTrue(locator.get(Mailer.class) == first, "the first registration should survive");
    }

    @Check(id = "locators-are-independent")
    void locatorsAreIndependent() {
        var a = new ServiceLocator();
        var b = new ServiceLocator();
        a.register(Mailer.class, (to, body) -> { });
        Expect.raises(IllegalStateException.class, () -> b.get(Mailer.class),
            "a second locator must not see the first one's services");
    }

    @Check(id = "one-concurrent-winner", timeoutMs = 4000)
    void oneConcurrentWinner() {
        var locator = new ServiceLocator();
        AtomicInteger next = new AtomicInteger();
        List<Boolean> results = Stress.race(8, () -> {
            try {
                locator.register(Mailer.class, (to, body) -> next.incrementAndGet());
                return true;
            } catch (IllegalStateException e) {
                return false;
            }
        });
        Expect.equal(1, (int) results.stream().filter(r -> r).count(), "threads whose registration won");
    }

    @Check(id = "signup-sends")
    void signupSends() {
        var locator = new ServiceLocator();
        List<String> sent = new ArrayList<>();
        locator.register(Mailer.class, (to, body) -> sent.add(to + ": " + body));
        new SignupService(locator).signUp("ana");
        Expect.equal(List.of("ana: Welcome"), sent, "mail sent");
    }

    @Check(id = "signup-fails-at-startup")
    void signupFailsAtStartup() {
        var locator = new ServiceLocator();
        var e = Expect.raises(IllegalStateException.class, () -> new SignupService(locator),
            "building SignupService without a Mailer");
        Expect.equal("no service registered for Mailer", e.getMessage(), "the message");
    }

    @Check(id = "locator-state-is-per-instance", kind = Kind.DESIGN)
    void locatorStateIsPerInstance() {
        for (var f : Types.named("ServiceLocator").getDeclaredFields()) {
            Expect.isTrue(!Modifier.isStatic(f.getModifiers()),
                "ServiceLocator." + f.getName() + " is shared by every locator; make it per instance");
        }
    }

    @Check(id = "consumer-resolves-once", kind = Kind.DESIGN)
    void consumerResolvesOnce() {
        var signup = Source.type("SignupService");
        Expect.none(signup.method("signUp").calls("get"),
            "signUp asks the locator on every call; resolve the Mailer when the service is built");
        var f = Types.onlyFieldOfType(Types.named("SignupService"), Mailer.class);
        Expect.isTrue(Modifier.isPrivate(f.getModifiers()) && Modifier.isFinal(f.getModifiers()),
            "SignupService." + f.getName() + " should be private final");
        Expect.isTrue(Types.fieldsOfType(Types.named("SignupService"), Types.named("ServiceLocator")).isEmpty(),
            "SignupService should not keep the locator after construction");
    }
}
