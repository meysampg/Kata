import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

final class EventStore {
    private final Map<String, List<StockEvent>> streams = new HashMap<>();

    List<StockEvent> load(String streamId) {
        return List.copyOf(streams.getOrDefault(streamId, List.of()));
    }

    void append(String streamId, int expectedVersion, List<StockEvent> events) {
        var stream = streams.computeIfAbsent(streamId, k -> new ArrayList<>());
        if (stream.size() != expectedVersion) {
            throw new VersionConflict("expected v" + expectedVersion
                + " but found v" + stream.size());
        }
        stream.addAll(events);
    }
}
