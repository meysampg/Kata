sealed interface Expr permits Num, Add, Mul, Neg {
    <R> R accept(ExprVisitor<R> visitor);
}

record Num(int value) implements Expr {
    public <R> R accept(ExprVisitor<R> visitor) {
        throw new UnsupportedOperationException("TODO");
    }
}

record Add(Expr left, Expr right) implements Expr {
    public <R> R accept(ExprVisitor<R> visitor) {
        throw new UnsupportedOperationException("TODO");
    }
}

record Mul(Expr left, Expr right) implements Expr {
    public <R> R accept(ExprVisitor<R> visitor) {
        throw new UnsupportedOperationException("TODO");
    }
}

record Neg(Expr operand) implements Expr {
    public <R> R accept(ExprVisitor<R> visitor) {
        throw new UnsupportedOperationException("TODO");
    }
}
