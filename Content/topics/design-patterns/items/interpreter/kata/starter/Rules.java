import java.util.Map;

// Eligibility rules over named flags, e.g. (and pro (not trial)).
// Each class below is a node of the rule tree.
record Flag(String name) implements Rule {
    public boolean eval(Map<String, Boolean> flags) {
        throw new UnsupportedOperationException("TODO");
    }
}

record Not(Rule operand) implements Rule {
    public boolean eval(Map<String, Boolean> flags) {
        throw new UnsupportedOperationException("TODO");
    }
}

record And(Rule left, Rule right) implements Rule {
    public boolean eval(Map<String, Boolean> flags) {
        throw new UnsupportedOperationException("TODO");
    }
}

record Or(Rule left, Rule right) implements Rule {
    public boolean eval(Map<String, Boolean> flags) {
        throw new UnsupportedOperationException("TODO");
    }
}

final class Rules {
    private Rules() { }

    /** Builds the tree for the text. It must not evaluate anything. */
    static Rule parse(String source) {
        throw new UnsupportedOperationException("TODO");
    }
}
