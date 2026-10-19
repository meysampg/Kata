// Every new customer tier is another case in this switch.
final class Pricer {
    long price(String tier, long cents) {
        return switch (tier) {
            case "VIP" -> cents * 90 / 100;
            case "STAFF" -> cents * 70 / 100;
            case "CLEARANCE" -> Math.max(cents - 500, 0);
            default -> cents;
        };
    }
}

// Callers use this entry point. Keep its signature and behaviour.
final class Pricing {
    private Pricing() { }

    static long price(String tier, long cents) {
        return new Pricer().price(tier, cents);
    }
}
