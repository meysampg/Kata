// [[state
sealed interface State permits Draft, Paid, Shipped, Cancelled {
    default State pay(String receipt) { throw reject("pay"); }
    default State ship(String tracking) { throw reject("ship"); }
    default State cancel() { throw reject("cancel"); }

    private IllegalStateException reject(String event) {
        return new IllegalStateException(event + " not allowed in " + this);
    }
}
// ]]

// [[concrete
record Draft() implements State {
    public State pay(String receipt) { return new Paid(receipt); }
    public State cancel() { return new Cancelled(); }
}

record Paid(String receipt) implements State {
    public State ship(String tracking) { return new Shipped(tracking); }
    public State cancel() { return new Cancelled(); }
}

record Shipped(String tracking) implements State {}

record Cancelled() implements State {}
// ]]

// [[context
final class Order {
    private State state = new Draft();

    void pay(String receipt) { state = state.pay(receipt); }
    void ship(String tracking) { state = state.ship(tracking); }
    void cancel() { state = state.cancel(); }
    State state() { return state; }
}
// ]]

class Main {
    public static void main(String[] args) {
        // [[client
        var order = new Order();
        order.pay("R-1");
        System.out.println(order.state());
        order.ship("TRK-9");
        System.out.println(order.state());
        try {
            order.cancel();
        } catch (IllegalStateException e) {
            System.out.println(e.getMessage());
        }
        // ]]
    }
}
