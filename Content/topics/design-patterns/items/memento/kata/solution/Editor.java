import java.util.ArrayDeque;
import java.util.Deque;

final class Editor {
    /** Opaque to everyone except Editor. */
    sealed interface Memento permits Snapshot { }

    private record Snapshot(String text, int cursor) implements Memento { }

    private StringBuilder text = new StringBuilder();
    private int cursor;

    String text() { return text.toString(); }

    int cursor() { return cursor; }

    void type(String s) {
        text.insert(cursor, s);
        cursor += s.length();
    }

    void delete(int count) {
        int n = Math.min(count, cursor);
        text.delete(cursor - n, cursor);
        cursor -= n;
    }

    void moveTo(int position) {
        cursor = Math.max(0, Math.min(position, text.length()));
    }

    Memento save() {
        return new Snapshot(text.toString(), cursor);
    }

    void restore(Memento memento) {
        var s = (Snapshot) memento;
        text = new StringBuilder(s.text());
        cursor = s.cursor();
    }
}

final class History {
    private final Editor editor;
    private final Deque<Editor.Memento> checkpoints = new ArrayDeque<>();

    History(Editor editor) { this.editor = editor; }

    void checkpoint() {
        checkpoints.push(editor.save());
    }

    boolean undo() {
        if (checkpoints.isEmpty()) {
            return false;
        }
        editor.restore(checkpoints.pop());
        return true;
    }
}
