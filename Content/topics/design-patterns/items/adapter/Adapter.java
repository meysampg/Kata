import java.util.Optional;

// [[target
record Point(double lat, double lon) {}

interface Locator {
    Optional<Point> locate(String address);
}
// ]]

// [[adaptee
final class LegacyGeoService {
    String lookup(String query) {
        return query.startsWith("Berlin") ? "52.52|13.40" : "";
    }
}
// ]]

// [[adapter
final class GeoAdapter implements Locator {
    private final LegacyGeoService legacy;

    GeoAdapter(LegacyGeoService legacy) { this.legacy = legacy; }

    public Optional<Point> locate(String address) {
        String raw = legacy.lookup(address);
        if (raw.isEmpty()) return Optional.empty();
        String[] parts = raw.split("\\|");
        return Optional.of(new Point(
            Double.parseDouble(parts[0]), Double.parseDouble(parts[1])));
    }
}
// ]]

class Main {
    public static void main(String[] args) {
        // [[client
        Locator locator = new GeoAdapter(new LegacyGeoService());
        System.out.println(locator.locate("Berlin, Mitte"));
        System.out.println(locator.locate("Atlantis"));
        // ]]
    }
}
