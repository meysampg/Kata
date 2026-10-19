final class Doc {
    private final StringBuilder text = new StringBuilder();

    void insert(int at, String s) { text.insert(at, s); }

    // Removes [from, to) and returns what was removed.
    String delete(int from, int to) {
        String removed = text.substring(from, to);
        text.delete(from, to);
        return removed;
    }

    String text() { return text.toString(); }
}

interface Command {
    void execute();

    void undo();
}
