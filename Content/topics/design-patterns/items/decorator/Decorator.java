import java.util.ArrayList;
import java.util.List;

// [[component
interface Notifier {
    void send(String message);
}
// ]]

// [[concrete
final class ConsoleNotifier implements Notifier {
    public void send(String message) {
        System.out.println("send: " + message);
    }
}
// ]]

// [[base
abstract class NotifierDecorator implements Notifier {
    protected final Notifier next;

    NotifierDecorator(Notifier next) { this.next = next; }
}
// ]]

// [[wrappers
final class Prefixed extends NotifierDecorator {
    private final String tag;

    Prefixed(Notifier next, String tag) { super(next); this.tag = tag; }

    public void send(String message) { next.send("[" + tag + "] " + message); }
}

final class Audited extends NotifierDecorator {
    private final List<String> log;

    Audited(Notifier next, List<String> log) { super(next); this.log = log; }

    public void send(String message) {
        log.add(message);
        next.send(message);
    }
}
// ]]

class Main {
    public static void main(String[] args) {
        // [[stack
        var log = new ArrayList<String>();
        Notifier notifier = new Audited(
            new Prefixed(new ConsoleNotifier(), "ops"), log);
        // ]]
        // [[client
        notifier.send("disk 91%");
        notifier.send("disk 95%");
        System.out.println("audited: " + log);
        // ]]
    }
}
