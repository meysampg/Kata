import java.util.ArrayList;
import java.util.List;

final class StockItem {
    private final List<StockEvent> pending = new ArrayList<>();
    private int onHand;
    private int version;

    static StockItem replay(List<StockEvent> history) {
        var item = new StockItem();
        history.forEach(item::apply);
        return item;
    }

    private void apply(StockEvent event) {
        switch (event) {
            case Received r -> onHand += r.units();
            case Picked p -> onHand -= p.units();
            case Adjusted a -> onHand += a.delta();
        }
        version++;
    }

    private void record(StockEvent event) {
        apply(event);
        pending.add(event);
    }

    void receive(int units) {
        if (units <= 0) throw new IllegalArgumentException("units");
        record(new Received(units));
    }

    void pick(int units) {
        if (units <= 0) throw new IllegalArgumentException("units");
        if (units > onHand) {
            throw new IllegalStateException("insufficient stock");
        }
        record(new Picked(units));
    }

    void adjust(int delta) {
        if (onHand + delta < 0) throw new IllegalStateException("below zero");
        record(new Adjusted(delta));
    }

    List<StockEvent> pendingEvents() { return List.copyOf(pending); }

    void saveTo(EventStore store, String streamId) {
        store.append(streamId, version - pending.size(), pending);
        pending.clear();
    }

    int onHand() { return onHand; }
    int version() { return version; }
}
