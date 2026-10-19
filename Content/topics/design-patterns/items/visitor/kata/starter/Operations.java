// Evaluates the tree: Num is its value, Neg negates, Add and Mul combine.
final class Eval implements ExprVisitor<Integer> {
    public Integer visitNum(Num n) {
        throw new UnsupportedOperationException("TODO");
    }

    public Integer visitAdd(Add a) {
        throw new UnsupportedOperationException("TODO");
    }

    public Integer visitMul(Mul m) {
        throw new UnsupportedOperationException("TODO");
    }

    public Integer visitNeg(Neg n) {
        throw new UnsupportedOperationException("TODO");
    }
}

// Prints fully parenthesised text: ((2 + 3) * 4) and -(5).
final class Show implements ExprVisitor<String> {
    public String visitNum(Num n) {
        throw new UnsupportedOperationException("TODO");
    }

    public String visitAdd(Add a) {
        throw new UnsupportedOperationException("TODO");
    }

    public String visitMul(Mul m) {
        throw new UnsupportedOperationException("TODO");
    }

    public String visitNeg(Neg n) {
        throw new UnsupportedOperationException("TODO");
    }
}

// Depth of the tree: a Num is 1, any other node is 1 + its deepest child.
final class Depth implements ExprVisitor<Integer> {
    public Integer visitNum(Num n) {
        throw new UnsupportedOperationException("TODO");
    }

    public Integer visitAdd(Add a) {
        throw new UnsupportedOperationException("TODO");
    }

    public Integer visitMul(Mul m) {
        throw new UnsupportedOperationException("TODO");
    }

    public Integer visitNeg(Neg n) {
        throw new UnsupportedOperationException("TODO");
    }
}
