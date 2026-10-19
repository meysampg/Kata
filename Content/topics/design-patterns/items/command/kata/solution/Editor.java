import java.util.ArrayDeque;
import java.util.Deque;

record Insert(Doc doc, int at, String s) implements Command {
    public void execute() { doc.insert(at, s); }

    public void undo() { doc.delete(at, at + s.length()); }
}

final class Delete implements Command {
    private final Doc doc;
    private final int from;
    private final int to;
    private String removed = ""; // captured on every execute

    Delete(Doc doc, int from, int to) {
        this.doc = doc;
        this.from = from;
        this.to = to;
    }

    public void execute() { removed = doc.delete(from, to); }

    public void undo() { doc.insert(from, removed); }
}

final class History {
    private final Deque<Command> done = new ArrayDeque<>();
    private final Deque<Command> undone = new ArrayDeque<>();

    void run(Command c) {
        c.execute();
        done.push(c);
        undone.clear();
    }

    void undo() {
        if (done.isEmpty()) return;
        Command c = done.pop();
        c.undo();
        undone.push(c);
    }

    void redo() {
        if (undone.isEmpty()) return;
        Command c = undone.pop();
        c.execute();
        done.push(c);
    }

    boolean canUndo() { return !done.isEmpty(); }

    boolean canRedo() { return !undone.isEmpty(); }
}
