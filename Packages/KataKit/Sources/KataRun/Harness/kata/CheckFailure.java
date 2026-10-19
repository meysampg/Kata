package kata;

/** A check failed. The message is shown to the learner, so it must be actionable. */
public final class CheckFailure extends RuntimeException {
    private static final long serialVersionUID = 1L;

    private final String file;
    private final int line;

    public CheckFailure(String message) {
        this(message, null, 0);
    }

    public CheckFailure(String message, String file, int line) {
        super(message);
        this.file = file;
        this.line = line;
    }

    /** File of the offending code in the learner's sources, or null. */
    public String file() {
        return file;
    }

    /** 1-based line of the offending code, or 0. */
    public int line() {
        return line;
    }
}
