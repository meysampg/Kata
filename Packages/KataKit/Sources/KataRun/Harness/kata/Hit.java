package kata;

/**
 * A place in the learner's sources found by {@link Source}. For method calls and {@code new}
 * expressions {@code args} is the source text of the arguments (for example {@code 5, TimeUnit.SECONDS}),
 * otherwise empty; {@code text} keeps its meaning (method name followed by {@code ()}, or {@code new T}).
 */
public record Hit(String file, int line, int column, boolean insideSynchronized, String text, String args) {
    public Hit(String file, int line, int column, boolean insideSynchronized, String text) {
        this(file, line, column, insideSynchronized, text, "");
    }

    @Override
    public String toString() {
        return file + ":" + line + (text == null || text.isEmpty() ? "" : " (" + text + ")");
    }
}
