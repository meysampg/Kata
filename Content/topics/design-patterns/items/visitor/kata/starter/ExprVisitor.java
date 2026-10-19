interface ExprVisitor<R> {
    R visitNum(Num n);

    R visitAdd(Add a);

    R visitMul(Mul m);

    R visitNeg(Neg n);
}
