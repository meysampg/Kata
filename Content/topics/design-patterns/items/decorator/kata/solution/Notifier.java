import java.util.List;

interface Notifier {
    void send(String message);
}

final class ListNotifier implements Notifier {
    private final List<String> out;

    ListNotifier(List<String> out) { this.out = out; }

    public void send(String message) { out.add(message); }
}

final class Prefixing implements Notifier {
    private final Notifier next;
    private final String tag;

    Prefixing(Notifier next, String tag) {
        this.next = next;
        this.tag = tag;
    }

    public void send(String message) { next.send("[" + tag + "] " + message); }
}

final class Shouting implements Notifier {
    private final Notifier next;

    Shouting(Notifier next) { this.next = next; }

    public void send(String message) { next.send(message.toUpperCase()); }
}

final class Notifiers {
    private Notifiers() { }

    static Notifier create(String tag, boolean shout, List<String> out) {
        Notifier n = new ListNotifier(out);
        if (tag != null) n = new Prefixing(n, tag);
        if (shout) n = new Shouting(n);
        return n;
    }
}
