import java.lang.reflect.Method;
import kata.*;

class FacadeKataTest {
    static final String ADDR = "Main St 1";

    @Check(id = "order-is-placed")
    void orderIsPlaced() {
        var shop = new Storefront();
        Expect.equal("OK TRK-A1-1", shop.buy(" a1 ", 2, "4111", ADDR), "first order");
        Expect.equal("OK TRK-B2-2", shop.buy("b2", 1, "4111", ADDR), "second order");
    }

    @Check(id = "out-of-stock")
    void outOfStock() {
        var shop = new Storefront();
        shop.buy("a1", 2, "4111", ADDR);
        Expect.equal("REJECTED stock", shop.buy("a1", 2, "4111", ADDR), "only 1 left");
    }

    @Check(id = "payment-failure-releases-stock")
    void paymentFailureReleasesStock() {
        var shop = new Storefront();
        Expect.equal("REJECTED payment", shop.buy("a1", 3, "0000-1", ADDR), "declined card");
        Expect.equal("OK TRK-A1-1", shop.buy("a1", 3, "4111", ADDR),
            "the declined order must give its stock back");
    }

    @Check(id = "nothing-booked-on-rejection")
    void nothingBookedOnRejection() {
        var shop = new Storefront();
        shop.buy("a1", 9, "4111", ADDR);
        shop.buy("a1", 1, "0000", ADDR);
        Expect.equal("OK TRK-A1-1", shop.buy("a1", 1, "4111", ADDR),
            "rejected orders must not consume tracking numbers");
    }

    @Check(id = "facade-has-place", kind = Kind.DESIGN)
    void facadeHasPlace() {
        Class<?> service = Types.named("OrderService");
        Method place = Types.method(service, "place",
            String.class, int.class, String.class, String.class);
        Expect.equal(Outcome.class, place.getReturnType(), "OrderService.place's return type");
    }

    @Check(id = "facade-owns-the-subsystems", kind = Kind.DESIGN)
    void facadeOwnsTheSubsystems() {
        Class<?> service = Types.named("OrderService");
        Types.onlyFieldOfType(service, Inventory.class);
        Types.onlyFieldOfType(service, Payments.class);
        Types.onlyFieldOfType(service, Shipping.class);
        Expect.isTrue(!Source.type("OrderService").calls("release").isEmpty(),
            "OrderService should undo the reservation when payment fails");
    }

    @Check(id = "storefront-sees-only-the-facade", kind = Kind.DESIGN)
    void storefrontSeesOnlyTheFacade() {
        var store = Source.type("Storefront");
        for (String sub : new String[] {"Inventory", "Payments", "Shipping"}) {
            Expect.none(store.mentions(sub), "Storefront still talks to " + sub);
        }
        Expect.none(store.calls("release"), "Storefront still compensates failed payments");
        Expect.isTrue(!store.mentions("OrderService").isEmpty(),
            "Storefront should go through OrderService");
    }

    @Check(id = "storefront-holds-no-subsystem", kind = Kind.DESIGN)
    void storefrontHoldsNoSubsystem() {
        Class<?> store = Types.named("Storefront");
        Expect.isTrue(Types.fieldsOfType(store, Inventory.class).isEmpty()
            && Types.fieldsOfType(store, Payments.class).isEmpty()
            && Types.fieldsOfType(store, Shipping.class).isEmpty(),
            "Storefront should not keep any subsystem as a field");
    }
}
