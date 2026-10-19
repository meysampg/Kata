final class Order {
    private OrderState state = new Fresh();

    void pay(String receipt) {
        state = state.pay(receipt);
    }

    void ship(String tracking) {
        state = state.ship(tracking);
    }

    void cancel() {
        state = state.cancel();
    }

    String describe() {
        return state.describe();
    }
}
