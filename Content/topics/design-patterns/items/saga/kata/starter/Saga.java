import java.util.List;

// Orchestrates a checkout across services that share no transaction.
final class Saga {
    Saga(List<Step> steps) {
        throw new UnsupportedOperationException("TODO");
    }

    /** Runs the steps in order. Returns true when every step succeeded. */
    boolean run() {
        throw new UnsupportedOperationException("TODO");
    }

    /** What happened, in order: "do x", "fail x", "undo x", "stuck x". */
    List<String> log() {
        throw new UnsupportedOperationException("TODO");
    }
}
