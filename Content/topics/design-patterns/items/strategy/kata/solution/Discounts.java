import java.math.BigDecimal;
import java.util.Map;

final class Discounts {
    private static final Map<String, DiscountPolicy> BY_CODE = Map.of(
        "NONE", subtotal -> subtotal,
        "SPRING10", new PercentOff(10),
        "WELCOME", new FlatOff(new BigDecimal("7.50")),
        "BULK", new AtLeast(new BigDecimal("100.00"), new PercentOff(15)));

    private Discounts() { }

    static DiscountPolicy forCode(String code) {
        DiscountPolicy policy = BY_CODE.get(code);
        if (policy == null) {
            throw new IllegalArgumentException("unknown code: " + code);
        }
        return policy;
    }
}
