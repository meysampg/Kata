import java.util.List;

final class EventStore {
    /** Every event of a stream, oldest first. Unknown streams are empty. */
    List<StockEvent> load(String streamId) {
        throw new UnsupportedOperationException("TODO");
    }

    /** Appends only if the stream has exactly expectedVersion events. */
    void append(String streamId, int expectedVersion, List<StockEvent> events) {
        throw new UnsupportedOperationException("TODO");
    }
}
