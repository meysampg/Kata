import java.util.OptionalDouble;

final class SensorThermometer implements Thermometer {
    private final LegacySensor sensor;

    SensorThermometer(LegacySensor sensor) { this.sensor = sensor; }

    public OptionalDouble celsius() {
        String raw = sensor.poll().trim();
        if (raw.isEmpty()) {
            return OptionalDouble.empty();
        }
        String[] parts = raw.split(":", 2);
        double value = Double.parseDouble(parts[1]);
        return switch (parts[0]) {
            case "C" -> OptionalDouble.of(value);
            case "F" -> OptionalDouble.of((value - 32) * 5 / 9);
            default -> throw new IllegalArgumentException("unit: " + raw);
        };
    }
}
