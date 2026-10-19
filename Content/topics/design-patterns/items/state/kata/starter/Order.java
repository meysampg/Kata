import java.util.Objects;

enum Status { NEW, PAID, SHIPPED, CANCELLED }

// Every new status means another case in every method of this class.
final class Order {
    private Status status = Status.NEW;
    private String receipt;
    private String tracking;

    void pay(String receipt) {
        switch (status) {
            case NEW -> {
                this.receipt = Objects.requireNonNull(receipt);
                status = Status.PAID;
            }
            default -> throw reject("pay");
        }
    }

    void ship(String tracking) {
        switch (status) {
            case PAID -> {
                this.tracking = Objects.requireNonNull(tracking);
                status = Status.SHIPPED;
            }
            default -> throw reject("ship");
        }
    }

    void cancel() {
        switch (status) {
            case NEW, PAID -> status = Status.CANCELLED;
            default -> throw reject("cancel");
        }
    }

    String describe() {
        return switch (status) {
            case NEW -> "New";
            case PAID -> "Paid[" + receipt + "]";
            case SHIPPED -> "Shipped[" + tracking + "]";
            case CANCELLED -> "Cancelled";
        };
    }

    private IllegalStateException reject(String event) {
        String where = describe();
        return new IllegalStateException(event + " not allowed in " + where);
    }
}
