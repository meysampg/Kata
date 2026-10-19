import java.util.List;

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
        String cut = text.length() > 30 ? text.substring(0, 27) + "..." : text;
        return "sms:" + to + " <- " + cut;
    }
}

abstract class Message {
    protected final Channel channel;

    protected Message(Channel channel) { this.channel = channel; }

    abstract String deliver(String to);
}

final class Alert extends Message {
    private final String problem;

    Alert(Channel channel, String problem) {
        super(channel);
        this.problem = problem;
    }

    String deliver(String to) { return channel.send(to, "ALERT: " + problem); }
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

final class Messages {
    private Messages() { }

    private static Channel channel(String name) {
        return switch (name) {
            case "email" -> new Email();
            case "sms" -> new Sms();
            default -> throw new IllegalArgumentException(name);
        };
    }

    static Message alert(String channel, String problem) {
        return new Alert(channel(channel), problem);
    }

    static Message digest(String channel, List<String> items) {
        return new Digest(channel(channel), items);
    }
}
