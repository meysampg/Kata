import java.lang.reflect.Constructor;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.util.List;
import kata.*;

class BridgeKataTest {
    static final List<String> ITEMS = List.of("a", "b");
    static final List<String> MANY = List.of("disk", "memory", "network", "cpu");

    @Check(id = "email-alert")
    void emailAlert() {
        Expect.equal("email:ann <- ALERT: disk full",
            Messages.alert("email", "disk full").deliver("ann"), "email alert");
    }

    @Check(id = "email-digest")
    void emailDigest() {
        Expect.equal("email:bo <- 2 items: [a, b]",
            Messages.digest("email", ITEMS).deliver("bo"), "email digest");
    }

    @Check(id = "sms-short-messages")
    void smsShortMessages() {
        Expect.equal("sms:ann <- ALERT: disk full",
            Messages.alert("sms", "disk full").deliver("ann"), "sms alert");
        Expect.equal("sms:bo <- 2 items: [a, b]",
            Messages.digest("sms", ITEMS).deliver("bo"), "sms digest");
    }

    @Check(id = "sms-cuts-long-messages")
    void smsCutsLongMessages() {
        Expect.equal("sms:bo <- 4 items: [disk, memory, net...",
            Messages.digest("sms", MANY).deliver("bo"), "long sms digest");
        Expect.equal("sms:ann <- ALERT: the database is on f...",
            Messages.alert("sms", "the database is on fire today").deliver("ann"), "long sms alert");
        Expect.equal("email:bo <- 4 items: [disk, memory, network, cpu]",
            Messages.digest("email", MANY).deliver("bo"), "email never cuts");
    }

    @Check(id = "unknown-channel")
    void unknownChannel() {
        Expect.raises(IllegalArgumentException.class,
            () -> Messages.alert("pager", "x"), "an unknown channel for an alert");
        Expect.raises(IllegalArgumentException.class,
            () -> Messages.digest("pager", ITEMS), "an unknown channel for a digest");
    }

    @Check(id = "channel-is-an-interface", kind = Kind.DESIGN)
    void channelIsAnInterface() {
        Class<?> channel = Types.named("Channel");
        Expect.isTrue(channel.isInterface(), "Channel should be an interface");
        Method send = Types.singleAbstractMethod(channel);
        Expect.equal(List.of(String.class, String.class), List.of(send.getParameterTypes()),
            "the parameters of Channel." + send.getName());
        Expect.equal(String.class, send.getReturnType(), "the return type of Channel." + send.getName());
    }

    @Check(id = "message-holds-the-channel", kind = Kind.DESIGN)
    void messageHoldsTheChannel() {
        Class<?> message = Types.named("Message");
        Expect.isTrue(Modifier.isAbstract(message.getModifiers()), "Message should stay abstract");
        Field f = Types.onlyFieldOfType(message, Types.named("Channel"));
        Expect.isTrue(Modifier.isFinal(f.getModifiers()), "Message." + f.getName() + " should be final");
        Types.constructor(message, Types.named("Channel"));
    }

    @Check(id = "combination-classes-are-gone", kind = Kind.DESIGN)
    void combinationClassesAreGone() {
        for (String name : List.of("EmailAlert", "SmsAlert", "EmailDigest", "SmsDigest")) {
            boolean exists = true;
            try {
                Types.named(name);
            } catch (CheckFailure e) {
                exists = false;
            }
            Expect.isTrue(!exists, name + " is still a class: a message kind and a channel should vary separately");
        }
    }

    @Check(id = "messages-accept-any-channel", kind = Kind.DESIGN)
    void messagesAcceptAnyChannel() throws Throwable {
        Class<?> channel = Types.named("Channel");
        Object pager = Types.implement(channel, a -> "pager:" + a[0] + "/" + a[1]);
        Constructor<?> alert = Types.constructor(Types.named("Alert"), channel, String.class);
        Constructor<?> digest = Types.constructor(Types.named("Digest"), channel, List.class);
        Object a = Types.create(alert, pager, "disk full");
        Object d = Types.create(digest, pager, ITEMS);
        Expect.equal("pager:ann/ALERT: disk full",
            Types.call(Types.method(a.getClass(), "deliver", String.class), a, "ann"),
            "an Alert over a channel it has never seen");
        Expect.equal("pager:bo/2 items: [a, b]",
            Types.call(Types.method(d.getClass(), "deliver", String.class), d, "bo"),
            "a Digest over a channel it has never seen");
    }

    @Check(id = "messages-do-not-know-channels", kind = Kind.DESIGN)
    void messagesDoNotKnowChannels() {
        Class<?> channel = Types.named("Channel");
        for (String name : List.of("Message", "Alert", "Digest")) {
            Class<?> type = Types.named(name);
            for (Field f : type.getDeclaredFields()) {
                Expect.isTrue(!isConcreteChannel(channel, f.getType()),
                    name + "." + f.getName() + " is a concrete channel; depend on Channel instead");
            }
            for (Constructor<?> c : type.getDeclaredConstructors()) {
                for (Class<?> p : c.getParameterTypes()) {
                    Expect.isTrue(!isConcreteChannel(channel, p),
                        name + " takes a concrete channel in its constructor");
                }
            }
            Expect.none(Source.type(name).comparedStrings(), name + " still branches on a channel name");
            Expect.none(Source.type(name).instanceofs(), name + " inspects the channel's concrete type");
        }
    }

    static boolean isConcreteChannel(Class<?> channel, Class<?> t) {
        return !t.isInterface() && channel.isAssignableFrom(t);
    }
}
