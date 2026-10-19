import java.util.Map;

@FunctionalInterface
interface PriceRule {
    long apply(long cents);
}

final class Tiers {
    private Tiers() { }

    static Map<String, PriceRule> standard() {
        return Map.of(
            "VIP", cents -> cents * 90 / 100,
            "STAFF", cents -> cents * 70 / 100,
            "CLEARANCE", cents -> Math.max(cents - 500, 0));
    }
}
