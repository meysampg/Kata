sealed interface Expr permits Num, Add, Mul, Neg {
    <R> R accept(ExprVisitor<R> visitor);
}

record Num(int value) implements Expr {
    public <R> R accept(ExprVisitor<R> visitor) {
        return visitor.visitNum(this);
    }
}

record Add(Expr left, Expr right) implements Expr {
    public <R> R accept(ExprVisitor<R> visitor) {
        return visitor.visitAdd(this);
    }
}

record Mul(Expr left, Expr right) implements Expr {
    public <R> R accept(ExprVisitor<R> visitor) {
        return visitor.visitMul(this);
    }
}

record Neg(Expr operand) implements Expr {
    public <R> R accept(ExprVisitor<R> visitor) {
        return visitor.visitNeg(this);
    }
}
