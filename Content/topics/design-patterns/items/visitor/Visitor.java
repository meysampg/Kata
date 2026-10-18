// [[visitor
interface Visitor<R> {
    R visitNum(Num n);
    R visitAdd(Add a);
    R visitMul(Mul m);
}
// ]]

// [[elements
sealed interface Expr permits Num, Add, Mul {
    <R> R accept(Visitor<R> v);
}

record Num(int value) implements Expr {
    public <R> R accept(Visitor<R> v) { return v.visitNum(this); }
}

record Add(Expr left, Expr right) implements Expr {
    public <R> R accept(Visitor<R> v) { return v.visitAdd(this); }
}

record Mul(Expr left, Expr right) implements Expr {
    public <R> R accept(Visitor<R> v) { return v.visitMul(this); }
}
// ]]

// [[eval
final class Eval implements Visitor<Integer> {
    public Integer visitNum(Num n) { return n.value(); }
    public Integer visitAdd(Add a) {
        return a.left().accept(this) + a.right().accept(this);
    }
    public Integer visitMul(Mul m) {
        return m.left().accept(this) * m.right().accept(this);
    }
}
// ]]

// [[show
final class Show implements Visitor<String> {
    public String visitNum(Num n) { return String.valueOf(n.value()); }
    public String visitAdd(Add a) {
        return "(" + a.left().accept(this) + " + "
            + a.right().accept(this) + ")";
    }
    public String visitMul(Mul m) {
        return m.left().accept(this) + " * " + m.right().accept(this);
    }
}
// ]]

class Main {
    public static void main(String[] args) {
        // [[client
        Expr e = new Mul(new Add(new Num(2), new Num(3)), new Num(4));
        System.out.println(e.accept(new Show()) + " = " + e.accept(new Eval()));
        // ]]
    }
}
