import java.math.BigDecimal;

@FunctionalInterface
interface DiscountPolicy {
    BigDecimal apply(BigDecimal subtotal);
}

record PercentOff(int percent) implements DiscountPolicy {
    PercentOff {
        if (percent < 0 || percent > 100) {
            throw new IllegalArgumentException("percent");
        }
    }
    public BigDecimal apply(BigDecimal subtotal) {
        return subtotal.multiply(BigDecimal.valueOf(100 - percent, 2));
    }
}

record FlatOff(BigDecimal amount) implements DiscountPolicy {
    public BigDecimal apply(BigDecimal subtotal) {
        return subtotal.subtract(amount).max(BigDecimal.ZERO);
    }
}

record AtLeast(BigDecimal threshold, DiscountPolicy then)
        implements DiscountPolicy {
    public BigDecimal apply(BigDecimal subtotal) {
        return subtotal.compareTo(threshold) >= 0
            ? then.apply(subtotal)
            : subtotal;
    }
}
