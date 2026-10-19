// A tiny text editor. type, delete and moveTo already work.
final class Editor {
    private StringBuilder text = new StringBuilder();
    private int cursor;

    String text() { return text.toString(); }

    int cursor() { return cursor; }

    void type(String s) {
        text.insert(cursor, s);
        cursor += s.length();
    }

    /** Removes up to count characters before the cursor. */
    void delete(int count) {
        int n = Math.min(count, cursor);
        text.delete(cursor - n, cursor);
        cursor -= n;
    }

    void moveTo(int position) {
        cursor = Math.max(0, Math.min(position, text.length()));
    }

    // TODO: return a snapshot of the editor's state.
    Object save() {
        throw new UnsupportedOperationException("TODO");
    }

    // TODO: put the editor back into the state of that snapshot.
    void restore(Object snapshot) {
        throw new UnsupportedOperationException("TODO");
    }
}

// The caretaker: remembers snapshots so the user can undo.
final class History {
    History(Editor editor) {
        // TODO
    }

    /** Remembers the editor's current state. */
    void checkpoint() {
        throw new UnsupportedOperationException("TODO");
    }

    /** Restores the latest checkpoint; false if there is none. */
    boolean undo() {
        throw new UnsupportedOperationException("TODO");
    }
}
