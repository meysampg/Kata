import java.util.Map;

final class Pricer {
    private final Map<String, PriceRule> rules;

    Pricer(Map<String, PriceRule> rules) {
        this.rules = Map.copyOf(rules);
    }

    long price(String tier, long cents) {
        return rules.getOrDefault(tier, c -> c).apply(cents);
    }
}

final class Pricing {
    private Pricing() { }

    static long price(String tier, long cents) {
        return new Pricer(Tiers.standard()).price(tier, cents);
    }
}
