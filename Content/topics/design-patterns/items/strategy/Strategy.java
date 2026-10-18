import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;
import java.util.Map;

// [[strategy
@FunctionalInterface
interface DiscountPolicy {
    BigDecimal apply(BigDecimal subtotal);
}
// ]]

// [[concrete
record PercentOff(int percent) implements DiscountPolicy {
    PercentOff {
        if (percent < 0 || percent > 100) {
            throw new IllegalArgumentException("percent");
        }
    }
    public BigDecimal apply(BigDecimal subtotal) {
        BigDecimal factor = BigDecimal.valueOf(100 - percent, 2);
        return subtotal.multiply(factor).setScale(2, RoundingMode.HALF_EVEN);
    }
}

record FlatOff(BigDecimal amount) implements DiscountPolicy {
    public BigDecimal apply(BigDecimal subtotal) {
        return subtotal.subtract(amount).max(BigDecimal.ZERO);
    }
}
// ]]

// [[context
final class Checkout {
    private final DiscountPolicy policy;

    Checkout(DiscountPolicy policy) { this.policy = policy; }

    BigDecimal total(List<BigDecimal> prices) {
        BigDecimal subtotal =
            prices.stream().reduce(BigDecimal.ZERO, BigDecimal::add);
        return policy.apply(subtotal);
    }
}
// ]]

class Main {
    public static void main(String[] args) {
        // [[lambda
        DiscountPolicy none = subtotal -> subtotal;
        // ]]
        // [[select
        Map<String, DiscountPolicy> byCode = Map.of(
            "NONE", none,
            "SPRING10", new PercentOff(10),
            "WELCOME", new FlatOff(new BigDecimal("7.50")));
        // ]]
        var prices = List.of(new BigDecimal("19.99"), new BigDecimal("30.01"));
        for (String code : List.of("NONE", "SPRING10", "WELCOME")) {
            // [[client
            var checkout = new Checkout(byCode.get(code));
            System.out.println(code + " -> " + checkout.total(prices));
            // ]]
        }
    }
}
