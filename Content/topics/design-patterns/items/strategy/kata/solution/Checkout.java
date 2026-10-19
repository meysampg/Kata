import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;
import java.util.Objects;

final class Checkout {
    private final DiscountPolicy policy;

    Checkout(DiscountPolicy policy) {
        this.policy = Objects.requireNonNull(policy, "policy");
    }

    BigDecimal total(List<BigDecimal> prices) {
        BigDecimal subtotal =
            prices.stream().reduce(BigDecimal.ZERO, BigDecimal::add);
        return policy.apply(subtotal).setScale(2, RoundingMode.HALF_EVEN);
    }
}

final class Pricing {
    private Pricing() { }

    static BigDecimal total(String code, List<BigDecimal> prices) {
        return new Checkout(Discounts.forCode(code)).total(prices);
    }
}
