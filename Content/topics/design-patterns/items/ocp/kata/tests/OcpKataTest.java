import java.lang.reflect.Method;
import java.util.Map;
import kata.*;

class OcpKataTest {
    @Check(id = "percent-tiers")
    void percentTiers() {
        Expect.equal(900L, Pricing.price("VIP", 1000), "VIP");
        Expect.equal(700L, Pricing.price("STAFF", 1000), "STAFF");
        Expect.equal(279L, Pricing.price("STAFF", 399), "STAFF rounds down");
    }

    @Check(id = "clearance-floor")
    void clearanceFloor() {
        Expect.equal(1500L, Pricing.price("CLEARANCE", 2000), "CLEARANCE on 20.00");
        Expect.equal(0L, Pricing.price("CLEARANCE", 300), "CLEARANCE never below zero");
    }

    @Check(id = "unknown-tier-pays-full")
    void unknownTierPaysFull() {
        Expect.equal(1000L, Pricing.price("GUEST", 1000), "an unknown tier");
        Expect.equal(1000L, Pricing.price("vip", 1000), "tiers are case sensitive");
    }

    @Check(id = "rule-interface", kind = Kind.DESIGN)
    void ruleInterface() {
        Class<?> rule = Types.named("PriceRule");
        Expect.isTrue(rule.isInterface(), "PriceRule should be an interface");
        Method m = Types.singleAbstractMethod(rule);
        Expect.equal("apply", m.getName(), "the method name");
        Expect.equal(long.class, m.getReturnType(), "apply's return type");
        Expect.equal(java.util.List.of(long.class), java.util.List.of(m.getParameterTypes()), "apply's parameters");
    }

    @Check(id = "pricer-does-not-branch", kind = Kind.DESIGN)
    void pricerDoesNotBranch() {
        var pricer = Source.type("Pricer");
        Expect.none(pricer.comparedStrings(), "Pricer still compares tier names");
        Expect.none(pricer.switches(), "Pricer still switches on the tier");
        Expect.none(pricer.instanceofs(), "Pricer inspects the concrete rule type");
    }

    @Check(id = "new-tier-needs-no-edit", kind = Kind.DESIGN)
    void newTierNeedsNoEdit() throws Throwable {
        Class<?> rule = Types.named("PriceRule");
        Object half = Types.implement(rule, args -> (Long) args[0] / 2);
        var ctor = Types.constructor(Types.named("Pricer"), Map.class);
        Object pricer = Types.create(ctor, Map.of("GOLD", half));
        Method price = Types.method(pricer.getClass(), "price", String.class, long.class);
        Expect.equal(500L, Types.call(price, pricer, "GOLD", 1000L), "a tier Pricer has never seen");
        Expect.equal(1000L, Types.call(price, pricer, "VIP", 1000L), "a tier missing from the map");
    }

    @Check(id = "tiers-defined-outside-pricer", kind = Kind.DESIGN)
    void tiersDefinedOutsidePricer() throws Throwable {
        Class<?> rule = Types.named("PriceRule");
        var ctor = Types.constructor(Types.named("Pricer"), Map.class);
        Object empty = Types.create(ctor, Map.of());
        Method price = Types.method(empty.getClass(), "price", String.class, long.class);
        for (String tier : java.util.List.of("VIP", "STAFF", "CLEARANCE")) {
            Expect.equal(1000L, Types.call(price, empty, tier, 1000L),
                "Pricer with no rules pricing " + tier
                    + " (Pricer itself should not know any tier)");
        }
        Method standard = Types.staticMethod(Types.named("Tiers"), "standard");
        Object tiers = Types.call(standard, null);
        Expect.isTrue(tiers instanceof Map<?, ?> m
                && m.keySet().equals(java.util.Set.of("VIP", "STAFF", "CLEARANCE"))
                && m.values().stream().allMatch(rule::isInstance),
            "Tiers.standard() should map VIP, STAFF and CLEARANCE to PriceRules");
    }
}
