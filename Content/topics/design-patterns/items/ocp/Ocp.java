import java.util.List;

// [[before
final class PricerBefore {
    long price(String customerType, long cents) {
        return switch (customerType) {        // every new tier edits this
            case "VIP" -> cents * 90 / 100;
            case "STAFF" -> cents * 70 / 100;
            default -> cents;
        };
    }
}
// ]]

// [[abstraction
@FunctionalInterface
interface PriceRule {
    long apply(long cents);
}
// ]]

// [[closed
final class Pricer {                          // closed for modification
    private final List<PriceRule> rules;

    Pricer(List<PriceRule> rules) { this.rules = List.copyOf(rules); }

    long price(long cents) {
        long result = cents;
        for (PriceRule rule : rules) result = rule.apply(result);
        return result;
    }
}
// ]]

// [[extensions
record PercentOff(int percent) implements PriceRule {
    public long apply(long cents) { return cents * (100 - percent) / 100; }
}

record MinimumPrice(long floor) implements PriceRule {
    public long apply(long cents) { return Math.max(cents, floor); }
}
// ]]

class Main {
    public static void main(String[] args) {
        var old = new PricerBefore();
        System.out.println("before VIP: " + old.price("VIP", 2000));

        var vip = new Pricer(List.of(new PercentOff(10)));
        System.out.println("after VIP: " + vip.price(2000));

        // [[plug
        var blackFriday = new Pricer(List.of(
            new PercentOff(10),
            new PercentOff(25),
            new MinimumPrice(1000),
            cents -> cents / 10 * 10));       // a lambda too
        // ]]
        System.out.println("black friday: " + blackFriday.price(2000));
        System.out.println("black friday floor: " + blackFriday.price(1200));
    }
}
