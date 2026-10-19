// Edits as objects, so they can be undone and redone.
final class Insert implements Command {
    Insert(Doc doc, int at, String s) {
        throw new UnsupportedOperationException("TODO");
    }

    public void execute() { throw new UnsupportedOperationException("TODO"); }

    public void undo() { throw new UnsupportedOperationException("TODO"); }
}

final class Delete implements Command {
    Delete(Doc doc, int from, int to) {
        throw new UnsupportedOperationException("TODO");
    }

    public void execute() { throw new UnsupportedOperationException("TODO"); }

    public void undo() { throw new UnsupportedOperationException("TODO"); }
}

// Runs commands and remembers them. It knows nothing about documents.
final class History {
    void run(Command c) { throw new UnsupportedOperationException("TODO"); }

    void undo() { throw new UnsupportedOperationException("TODO"); }

    void redo() { throw new UnsupportedOperationException("TODO"); }

    boolean canUndo() { throw new UnsupportedOperationException("TODO"); }

    boolean canRedo() { throw new UnsupportedOperationException("TODO"); }
}
