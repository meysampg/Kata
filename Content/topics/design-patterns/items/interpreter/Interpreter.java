import java.util.ArrayDeque;
import java.util.Deque;
import java.util.List;
import java.util.Map;

// [[grammar
sealed interface Expr permits Num, Var, Add, Mul {
    int eval(Map<String, Integer> env);
}
// ]]

// [[terminals
record Num(int value) implements Expr {
    public int eval(Map<String, Integer> env) { return value; }
}

record Var(String name) implements Expr {
    public int eval(Map<String, Integer> env) {
        Integer v = env.get(name);
        if (v == null) throw new IllegalStateException("unbound " + name);
        return v;
    }
}
// ]]

// [[nonterminals
record Add(Expr left, Expr right) implements Expr {
    public int eval(Map<String, Integer> env) {
        return left.eval(env) + right.eval(env);
    }
}

record Mul(Expr left, Expr right) implements Expr {
    public int eval(Map<String, Integer> env) {
        return left.eval(env) * right.eval(env);
    }
}
// ]]

// [[parser
final class Parser {
    private final Deque<String> tokens;

    Parser(String src) {
        String s = src.replace("(", " ( ").replace(")", " ) ").trim();
        tokens = new ArrayDeque<>(List.of(s.split("\\s+")));
    }

    Expr parse() {
        String t = tokens.removeFirst();
        if (!t.equals("(")) {
            return Character.isDigit(t.charAt(0))
                ? new Num(Integer.parseInt(t)) : new Var(t);
        }
        String op = tokens.removeFirst();
        Expr left = parse();
        Expr right = parse();
        tokens.removeFirst(); // the closing ")"
        return switch (op) {
            case "+" -> new Add(left, right);
            case "*" -> new Mul(left, right);
            default -> throw new IllegalArgumentException("op " + op);
        };
    }
}
// ]]

class Main {
    public static void main(String[] args) {
        // [[client
        Expr e = new Parser("(+ 2 (* x 3))").parse();
        System.out.println(e);
        System.out.println(e.eval(Map.of("x", 5)));
        // ]]
    }
}
