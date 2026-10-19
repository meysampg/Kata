final class Eval implements ExprVisitor<Integer> {
    public Integer visitNum(Num n) {
        return n.value();
    }

    public Integer visitAdd(Add a) {
        return a.left().accept(this) + a.right().accept(this);
    }

    public Integer visitMul(Mul m) {
        return m.left().accept(this) * m.right().accept(this);
    }

    public Integer visitNeg(Neg n) {
        return -n.operand().accept(this);
    }
}

final class Show implements ExprVisitor<String> {
    public String visitNum(Num n) {
        return String.valueOf(n.value());
    }

    public String visitAdd(Add a) {
        String l = a.left().accept(this);
        return "(" + l + " + " + a.right().accept(this) + ")";
    }

    public String visitMul(Mul m) {
        String l = m.left().accept(this);
        return "(" + l + " * " + m.right().accept(this) + ")";
    }

    public String visitNeg(Neg n) {
        return "-(" + n.operand().accept(this) + ")";
    }
}

final class Depth implements ExprVisitor<Integer> {
    public Integer visitNum(Num n) {
        return 1;
    }

    public Integer visitAdd(Add a) {
        return 1 + Math.max(a.left().accept(this), a.right().accept(this));
    }

    public Integer visitMul(Mul m) {
        return 1 + Math.max(m.left().accept(this), m.right().accept(this));
    }

    public Integer visitNeg(Neg n) {
        return 1 + n.operand().accept(this);
    }
}
