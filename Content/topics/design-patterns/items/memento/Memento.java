import java.util.ArrayDeque;
import java.util.Deque;

// [[originator
final class Editor {
    /** Opaque to everyone except Editor; sealed so no one can forge one. */
    sealed interface Memento permits Snapshot {}

    private record Snapshot(String text, int cursor) implements Memento {}

    private StringBuilder text = new StringBuilder();
    private int cursor;

    void type(String s) {
        text.insert(cursor, s);
        cursor += s.length();
    }

    Memento save() { return new Snapshot(text.toString(), cursor); }

    void restore(Memento m) {
        var s = (Snapshot) m;
        text = new StringBuilder(s.text());
        cursor = s.cursor();
    }

    @Override public String toString() { return text + "@" + cursor; }
}
// ]]

// [[caretaker
final class History {
    private final Deque<Editor.Memento> stack = new ArrayDeque<>();

    void push(Editor.Memento m) { stack.push(m); }
    Editor.Memento pop() { return stack.pop(); }
}
// ]]

class Main {
    public static void main(String[] args) {
        var editor = new Editor();
        var history = new History();
        // [[checkpoint
        history.push(editor.save());
        editor.type("Hello");
        history.push(editor.save());
        editor.type(", world");
        // ]]
        System.out.println(editor);
        // [[undo
        editor.restore(history.pop());
        System.out.println(editor);
        editor.restore(history.pop());
        System.out.println(editor);
        // ]]
    }
}
