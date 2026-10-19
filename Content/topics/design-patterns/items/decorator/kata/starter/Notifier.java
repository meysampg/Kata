import java.util.List;

interface Notifier {
    void send(String message);
}

final class ListNotifier implements Notifier {
    private final List<String> out;

    ListNotifier(List<String> out) { this.out = out; }

    public void send(String message) { out.add(message); }
}

// One subclass per combination: a third option doubles the list again.
final class PrefixedListNotifier extends ListNotifierBase {
    PrefixedListNotifier(List<String> out, String tag) {
        super(out, tag, false);
    }
}

final class ShoutingListNotifier extends ListNotifierBase {
    ShoutingListNotifier(List<String> out) { super(out, null, true); }
}

final class ShoutingPrefixedListNotifier extends ListNotifierBase {
    ShoutingPrefixedListNotifier(List<String> out, String tag) {
        super(out, tag, true);
    }
}

abstract class ListNotifierBase implements Notifier {
    private final List<String> out;
    private final String tag;
    private final boolean shout;

    ListNotifierBase(List<String> out, String tag, boolean shout) {
        this.out = out; this.tag = tag; this.shout = shout;
    }

    public void send(String message) {
        String text = shout ? message.toUpperCase() : message;
        out.add(tag == null ? text : "[" + tag + "] " + text);
    }
}

// Callers use this entry point. Keep its signature and behaviour.
final class Notifiers {
    private Notifiers() { }

    static Notifier create(String tag, boolean shout, List<String> out) {
        if (tag != null && shout) {
            return new ShoutingPrefixedListNotifier(out, tag);
        }
        if (tag != null) return new PrefixedListNotifier(out, tag);
        if (shout) return new ShoutingListNotifier(out);
        return new ListNotifier(out);
    }
}
