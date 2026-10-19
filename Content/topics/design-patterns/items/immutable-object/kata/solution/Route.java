import java.util.ArrayList;
import java.util.Date;
import java.util.List;

final class Route {
    private final String name;
    private final List<String> stops;
    private final Date departure;

    Route(String name, List<String> stops, Date departure) {
        this.name = name;
        this.stops = List.copyOf(stops);
        this.departure = new Date(departure.getTime());
    }

    String name() {
        return name;
    }

    List<String> stops() {
        return stops;
    }

    Date departure() {
        return new Date(departure.getTime());
    }

    Route withName(String newName) {
        return new Route(newName, stops, departure);
    }

    Route withStop(String stop) {
        List<String> next = new ArrayList<>(stops);
        next.add(stop);
        return new Route(name, next, departure);
    }

    static Route sample() {
        List<String> stops = new ArrayList<>(List.of("A", "B"));
        return new Route("R1", stops, new Date(0L));
    }
}
