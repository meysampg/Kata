import java.lang.reflect.Constructor;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.math.BigDecimal;
import java.util.List;
import kata.*;

class StrategyKataTest {
    static final List<BigDecimal> CART =
        List.of(new BigDecimal("19.99"), new BigDecimal("30.01"));

    static String total(String code, List<BigDecimal> prices) {
        return Pricing.total(code, prices).toPlainString();
    }

    @Check(id = "known-codes")
    void knownCodes() {
        Expect.equal("50.00", total("NONE", CART), "NONE");
        Expect.equal("45.00", total("SPRING10", CART), "SPRING10");
        Expect.equal("42.50", total("WELCOME", CART), "WELCOME");
    }

    @Check(id = "flat-floors-at-zero")
    void flatFloorsAtZero() {
        Expect.equal("0.00", total("WELCOME", List.of(new BigDecimal("5.00"))),
            "WELCOME on a 5.00 cart");
    }

    @Check(id = "bulk-threshold")
    void bulkThreshold() {
        Expect.equal("99.99", total("BULK", List.of(new BigDecimal("99.99"))), "BULK below 100");
        Expect.equal("85.00", total("BULK", List.of(new BigDecimal("100.00"))), "BULK at 100");
    }

    @Check(id = "unknown-code")
    void unknownCode() {
        Expect.raises(IllegalArgumentException.class,
            () -> Pricing.total("BOGUS", CART), "an unknown code");
    }

    @Check(id = "policy-interface", kind = Kind.DESIGN)
    void policyInterface() {
        Class<?> policy = Types.named("DiscountPolicy");
        Expect.isTrue(policy.isInterface(), "DiscountPolicy should be an interface");
        Method apply = Types.singleAbstractMethod(policy);
        Expect.equal("apply", apply.getName(), "the method name");
        Expect.equal(List.of(BigDecimal.class), List.of(apply.getParameterTypes()), "apply's parameters");
        Expect.equal(BigDecimal.class, apply.getReturnType(), "apply's return type");
    }

    @Check(id = "checkout-holds-policy", kind = Kind.DESIGN)
    void checkoutHoldsPolicy() {
        Class<?> policy = Types.named("DiscountPolicy");
        Class<?> checkout = Types.named("Checkout");
        Field f = Types.onlyFieldOfType(checkout, policy);
        int m = f.getModifiers();
        Expect.isTrue(Modifier.isPrivate(m) && Modifier.isFinal(m),
            "Checkout." + f.getName() + " should be private final");
        Expect.isTrue(Types.fieldsOfType(checkout, String.class).isEmpty(),
            "Checkout should no longer keep the discount code");
        Types.constructor(checkout, policy);   // fails: "Checkout needs a constructor Checkout(DiscountPolicy)"
    }

    @Check(id = "checkout-does-not-branch", kind = Kind.DESIGN)
    void checkoutDoesNotBranch() {
        var checkout = Source.type("Checkout");
        Expect.none(checkout.comparedStrings(), "Checkout still compares discount codes");
        Expect.none(checkout.switches(), "Checkout still switches on the discount");
        Expect.none(checkout.instanceofs(), "Checkout inspects the policy's concrete type");
    }

    @Check(id = "any-policy-works", kind = Kind.DESIGN)
    void anyPolicyWorks() throws Exception {
        Class<?> policy = Types.named("DiscountPolicy");
        Object half = Types.implement(policy, args -> ((BigDecimal) args[0]).divide(BigDecimal.TWO));
        Constructor<?> c = Types.constructor(Types.named("Checkout"), policy);
        Object checkout = c.newInstance(half);
        Method total = Types.method(checkout.getClass(), "total", List.class);
        Expect.equal("25.00", ((BigDecimal) total.invoke(checkout, CART)).toPlainString(),
            "Checkout with a policy it has never seen");
    }

    @Check(id = "lookup-in-discounts", kind = Kind.DESIGN)
    void lookupInDiscounts() throws Exception {
        Class<?> policy = Types.named("DiscountPolicy");
        Method forCode = Types.staticMethod(Types.named("Discounts"), "forCode", String.class);
        Expect.isTrue(policy.isAssignableFrom(forCode.getReturnType()),
            "Discounts.forCode should return a DiscountPolicy");
        Expect.isTrue(policy.isInstance(forCode.invoke(null, "SPRING10")),
            "SPRING10 should resolve to a policy");
    }
}
