import java.util.OptionalDouble;

// Adapts LegacySensor to Thermometer.
//   "C:21.5" -> 21.5      "F:212" -> 100.0      "" -> empty
// Any other unit (for example "K:300") throws IllegalArgumentException.
// Every celsius() call polls the sensor exactly once.
final class SensorThermometer implements Thermometer {
    SensorThermometer(LegacySensor sensor) { }

    public OptionalDouble celsius() {
        throw new UnsupportedOperationException("TODO");
    }
}
