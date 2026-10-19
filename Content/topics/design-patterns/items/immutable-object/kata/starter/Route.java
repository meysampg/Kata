import java.util.ArrayList;
import java.util.Date;
import java.util.List;

// Meant to be an immutable value shared between threads. It is not.
final class Route {
    private String name;
    private final List<String> stops;
    private final Date departure;

    Route(String name, List<String> stops, Date departure) {
        this.name = name;
        this.stops = stops;
        this.departure = departure;
    }

    String name() {
        return name;
    }

    List<String> stops() {
        return stops;
    }

    Date departure() {
        return departure;
    }

    // Derive a route with another name.
    Route withName(String newName) {
        this.name = newName;
        return this;
    }

    // Derive a route with one more stop at the end.
    Route withStop(String stop) {
        stops.add(stop);
        return this;
    }

    static Route sample() {
        List<String> stops = new ArrayList<>(List.of("A", "B"));
        return new Route("R1", stops, new Date(0L));
    }
}
