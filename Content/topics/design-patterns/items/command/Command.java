import java.util.ArrayDeque;
import java.util.Deque;

// [[receiver
final class Doc {
    final StringBuilder text = new StringBuilder();
}
// ]]

// [[command
interface Command {
    void execute();
    void undo();
}
// ]]

// [[concrete
record Insert(Doc doc, int at, String s) implements Command {
    public void execute() { doc.text.insert(at, s); }

    public void undo() { doc.text.delete(at, at + s.length()); }
}

final class Delete implements Command {
    private final Doc doc;
    private final int from, to;
    private String removed = ""; // captured so undo can restore it

    Delete(Doc doc, int from, int to) {
        this.doc = doc; this.from = from; this.to = to;
    }

    public void execute() {
        removed = doc.text.substring(from, to);
        doc.text.delete(from, to);
    }

    public void undo() { doc.text.insert(from, removed); }
}
// ]]

// [[invoker
final class History {
    private final Deque<Command> done = new ArrayDeque<>();

    void run(Command c) { c.execute(); done.push(c); }

    void undo() { if (!done.isEmpty()) done.pop().undo(); }
}
// ]]

class Main {
    public static void main(String[] args) {
        // [[client
        var doc = new Doc();
        var history = new History();
        history.run(new Insert(doc, 0, "Hello"));
        history.run(new Insert(doc, 5, " world"));
        history.run(new Delete(doc, 0, 6));
        System.out.println(doc.text);
        history.undo();
        System.out.println(doc.text);
        history.undo();
        System.out.println(doc.text);
        // ]]
    }
}
