import java.util.List;

// One SKU. Its state is whatever the events add up to.
final class StockItem {
    private int onHand;
    private int version;

    static StockItem replay(List<StockEvent> history) {
        throw new UnsupportedOperationException("TODO");
    }

    void receive(int units) {
        throw new UnsupportedOperationException("TODO");
    }

    void pick(int units) {
        throw new UnsupportedOperationException("TODO");
    }

    void adjust(int delta) {
        throw new UnsupportedOperationException("TODO");
    }

    List<StockEvent> pendingEvents() {
        throw new UnsupportedOperationException("TODO");
    }

    void saveTo(EventStore store, String streamId) {
        throw new UnsupportedOperationException("TODO");
    }

    int onHand() { return onHand; }
    int version() { return version; }
}
