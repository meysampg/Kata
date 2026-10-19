package kata;

/** A place in the learner's sources found by {@link Source}. */
public record Hit(String file, int line, int column, boolean insideSynchronized, String text) {
    @Override
    public String toString() {
        return file + ":" + line + (text == null || text.isEmpty() ? "" : " (" + text + ")");
    }
}
