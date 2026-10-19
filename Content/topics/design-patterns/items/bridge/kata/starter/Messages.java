import java.util.List;

abstract class Message {
    abstract String deliver(String to);
}

// Two kinds of message times two channels: one class per combination.
final class EmailAlert extends Message {
    private final String problem;
    EmailAlert(String problem) { this.problem = problem; }
    String deliver(String to) {
        return "email:" + to + " <- ALERT: " + problem;
    }
}

final class SmsAlert extends Message {
    private final String problem;
    SmsAlert(String problem) { this.problem = problem; }
    String deliver(String to) {
        return "sms:" + to + " <- " + cut("ALERT: " + problem);
    }
    private static String cut(String s) {
        return s.length() > 30 ? s.substring(0, 27) + "..." : s;
    }
}

final class EmailDigest extends Message {
    private final List<String> items;
    EmailDigest(List<String> items) { this.items = items; }
    String deliver(String to) {
        return "email:" + to + " <- " + items.size() + " items: " + items;
    }
}

final class SmsDigest extends Message {
    private final List<String> items;
    SmsDigest(List<String> items) { this.items = items; }
    String deliver(String to) {
        return "sms:" + to + " <- " + cut(items.size() + " items: " + items);
    }
    private static String cut(String s) {
        return s.length() > 30 ? s.substring(0, 27) + "..." : s;
    }
}

// Callers use these entry points. Keep their signatures and behaviour.
final class Messages {
    private Messages() { }

    static Message alert(String channel, String problem) {
        return switch (channel) {
            case "email" -> new EmailAlert(problem);
            case "sms" -> new SmsAlert(problem);
            default -> throw new IllegalArgumentException(channel);
        };
    }

    static Message digest(String channel, List<String> items) {
        return switch (channel) {
            case "email" -> new EmailDigest(items);
            case "sms" -> new SmsDigest(items);
            default -> throw new IllegalArgumentException(channel);
        };
    }
}
