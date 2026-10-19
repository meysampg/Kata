import java.util.ArrayDeque;
import java.util.Deque;
import java.util.List;
import java.util.Map;

record Flag(String name) implements Rule {
    public boolean eval(Map<String, Boolean> flags) {
        Boolean value = flags.get(name);
        if (value == null) {
            throw new IllegalStateException("unbound " + name);
        }
        return value;
    }
}

record Not(Rule operand) implements Rule {
    public boolean eval(Map<String, Boolean> flags) {
        return !operand.eval(flags);
    }
}

record And(Rule left, Rule right) implements Rule {
    public boolean eval(Map<String, Boolean> flags) {
        return left.eval(flags) && right.eval(flags);
    }
}

record Or(Rule left, Rule right) implements Rule {
    public boolean eval(Map<String, Boolean> flags) {
        return left.eval(flags) || right.eval(flags);
    }
}

final class Rules {
    private Rules() { }

    static Rule parse(String source) {
        String spaced = source.replace("(", " ( ").replace(")", " ) ");
        Deque<String> tokens =
            new ArrayDeque<>(List.of(spaced.trim().split("\\s+")));
        Rule rule = read(tokens);
        if (!tokens.isEmpty()) {
            throw new IllegalArgumentException("extra input: " + tokens);
        }
        return rule;
    }

    private static Rule read(Deque<String> tokens) {
        String token = next(tokens);
        if (token.equals(")")) {
            throw new IllegalArgumentException("unexpected )");
        }
        if (!token.equals("(")) {
            if (!token.matches("[a-z][a-z0-9_]*")) {
                throw new IllegalArgumentException("bad flag: " + token);
            }
            return new Flag(token);
        }
        String op = next(tokens);
        Rule rule = switch (op) {
            case "not" -> new Not(read(tokens));
            case "and" -> new And(read(tokens), read(tokens));
            case "or" -> new Or(read(tokens), read(tokens));
            default -> throw new IllegalArgumentException("operator: " + op);
        };
        if (!next(tokens).equals(")")) {
            throw new IllegalArgumentException("expected )");
        }
        return rule;
    }

    private static String next(Deque<String> tokens) {
        if (tokens.isEmpty()) {
            throw new IllegalArgumentException("unexpected end");
        }
        return tokens.removeFirst();
    }
}
