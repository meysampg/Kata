import java.util.List;

// [[implementor
interface Channel {
    String send(String to, String text);
}

record Email() implements Channel {
    public String send(String to, String text) {
        return "email:" + to + " <- " + text;
    }
}

record Sms() implements Channel {
    public String send(String to, String text) {
        return "sms:" + to + " <- " + text;
    }
}
// ]]

// [[abstraction
abstract class Message {
    protected final Channel channel;

    protected Message(Channel channel) { this.channel = channel; }

    abstract String deliver(String to);
}
// ]]

// [[refined
final class Alert extends Message {
    private final String problem;

    Alert(Channel channel, String problem) {
        super(channel);
        this.problem = problem;
    }

    String deliver(String to) {
        return channel.send(to, "ALERT: " + problem);
    }
}

final class Digest extends Message {
    private final List<String> items;

    Digest(Channel channel, List<String> items) {
        super(channel);
        this.items = items;
    }

    String deliver(String to) {
        return channel.send(to, items.size() + " items: " + items);
    }
}
// ]]

class Main {
    public static void main(String[] args) {
        // [[client
        for (Channel ch : List.of(new Email(), new Sms())) {
            System.out.println(new Alert(ch, "disk full").deliver("ann"));
            System.out.println(new Digest(ch, List.of("a", "b")).deliver("bo"));
        }
        // ]]
    }
}
