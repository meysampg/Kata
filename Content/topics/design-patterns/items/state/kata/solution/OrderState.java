import java.util.Objects;

interface OrderState {
    default OrderState pay(String receipt) {
        throw reject("pay");
    }

    default OrderState ship(String tracking) {
        throw reject("ship");
    }

    default OrderState cancel() {
        throw reject("cancel");
    }

    String describe();

    private IllegalStateException reject(String event) {
        String where = describe();
        return new IllegalStateException(event + " not allowed in " + where);
    }
}

record Fresh() implements OrderState {
    public OrderState pay(String receipt) {
        return new Paid(Objects.requireNonNull(receipt));
    }

    public OrderState cancel() {
        return new Cancelled();
    }

    public String describe() {
        return "New";
    }
}

record Paid(String receipt) implements OrderState {
    public OrderState ship(String tracking) {
        return new Shipped(Objects.requireNonNull(tracking));
    }

    public OrderState cancel() {
        return new Cancelled();
    }

    public String describe() {
        return "Paid[" + receipt + "]";
    }
}

record Shipped(String tracking) implements OrderState {
    public String describe() {
        return "Shipped[" + tracking + "]";
    }
}

record Cancelled() implements OrderState {
    public String describe() {
        return "Cancelled";
    }
}
