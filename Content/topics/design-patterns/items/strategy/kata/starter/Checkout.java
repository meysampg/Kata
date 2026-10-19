import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;

// Marketing adds a promotion every month, and every time this class changes.
final class Checkout {
    private final String code;

    Checkout(String code) { this.code = code; }

    BigDecimal total(List<BigDecimal> prices) {
        BigDecimal subtotal =
            prices.stream().reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal result;
        if (code.equals("NONE")) {
            result = subtotal;
        } else if (code.equals("SPRING10")) {
            result = subtotal.multiply(new BigDecimal("0.90"));
        } else if (code.equals("WELCOME")) {
            result = subtotal.subtract(new BigDecimal("7.50"))
                .max(BigDecimal.ZERO);
        } else if (code.equals("BULK")) {
            result = subtotal.compareTo(new BigDecimal("100.00")) >= 0
                ? subtotal.multiply(new BigDecimal("0.85"))
                : subtotal;
        } else {
            throw new IllegalArgumentException("unknown code: " + code);
        }
        return result.setScale(2, RoundingMode.HALF_EVEN);
    }
}

// Callers use this entry point. Keep its signature and behaviour.
final class Pricing {
    private Pricing() { }

    static BigDecimal total(String code, List<BigDecimal> prices) {
        return new Checkout(code).total(prices);
    }
}
