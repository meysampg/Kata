import java.util.ArrayList;
import java.util.List;
import kata.*;

class VisitorKataTest {
    // ((2 + 3) * 4) + -(5)
    static final Expr TREE = new Add(
        new Mul(new Add(new Num(2), new Num(3)), new Num(4)),
        new Neg(new Num(5)));

    /** Not part of the kata: a visitor written by "someone else". */
    static final class Count implements ExprVisitor<Integer> {
        public Integer visitNum(Num n) { return 1; }
        public Integer visitAdd(Add a) { return 1 + a.left().accept(this) + a.right().accept(this); }
        public Integer visitMul(Mul m) { return 1 + m.left().accept(this) + m.right().accept(this); }
        public Integer visitNeg(Neg n) { return 1 + n.operand().accept(this); }
    }

    /** Records which visit method each node picks. */
    static final class Spy implements ExprVisitor<String> {
        public String visitNum(Num n) { return "num"; }
        public String visitAdd(Add a) { return "add"; }
        public String visitMul(Mul m) { return "mul"; }
        public String visitNeg(Neg n) { return "neg"; }
    }

    @Check(id = "eval")
    void eval() {
        Expect.equal(15, TREE.accept(new Eval()), "value of the tree");
        Expect.equal(-7, new Neg(new Num(7)).accept(new Eval()), "a negated number");
    }

    @Check(id = "show")
    void show() {
        Expect.equal("(((2 + 3) * 4) + -(5))", TREE.accept(new Show()), "text of the tree");
        Expect.equal("9", new Num(9).accept(new Show()), "a lone number");
    }

    @Check(id = "depth")
    void depth() {
        Expect.equal(4, TREE.accept(new Depth()), "depth of the tree");
        Expect.equal(1, new Num(1).accept(new Depth()), "depth of a number");
    }

    @Check(id = "each-node-picks-its-method")
    void eachNodePicksItsMethod() {
        Spy spy = new Spy();
        Expect.equal("num", new Num(1).accept(spy), "Num.accept");
        Expect.equal("add", new Add(new Num(1), new Num(2)).accept(spy), "Add.accept");
        Expect.equal("mul", new Mul(new Num(1), new Num(2)).accept(spy), "Mul.accept");
        Expect.equal("neg", new Neg(new Num(1)).accept(spy), "Neg.accept");
    }

    @Check(id = "new-operation-needs-no-change")
    void newOperationNeedsNoChange() {
        Expect.equal(8, TREE.accept(new Count()), "node count from a visitor the nodes never saw");
    }

    @Check(id = "operations-do-not-test-types", kind = Kind.DESIGN)
    void operationsDoNotTestTypes() {
        for (String name : List.of("Eval", "Show", "Depth")) {
            for (Class<?> c = Types.named(name); c != null
                    && c.getClassLoader() == Eval.class.getClassLoader(); c = c.getSuperclass()) {
                var op = Source.type(c.getSimpleName());
                String who = c.getSimpleName();
                Expect.none(op.instanceofs(), who + " asks nodes for their type with instanceof");
                Expect.none(op.switches(), who + " switches on node types instead of dispatching");
            }
        }
    }

    @Check(id = "operations-recurse-through-accept", kind = Kind.DESIGN)
    void operationsRecurseThroughAccept() {
        for (String name : List.of("Eval", "Show", "Depth")) {
            // The accept calls may sit in a shared base class the learner wrote.
            boolean recurses = false;
            for (Class<?> c = Types.named(name); c != null
                    && c.getClassLoader() == Eval.class.getClassLoader(); c = c.getSuperclass()) {
                recurses |= !Source.type(c.getSimpleName()).calls("accept").isEmpty();
            }
            Expect.isTrue(recurses, name + " should reach child nodes through accept(this)");
        }
    }

    @Check(id = "nodes-know-no-operations", kind = Kind.DESIGN)
    void nodesKnowNoOperations() {
        List<String> ops = List.of("Eval", "Show", "Depth");
        List<kata.Hit> hits = new ArrayList<>();
        for (String node : List.of("Num", "Add", "Mul", "Neg", "Expr")) {
            for (String op : ops) {
                hits.addAll(Source.type(node).mentions(op));
            }
        }
        Expect.none(hits, "A node class mentions an operation; operations should live in visitors only");
    }
}
