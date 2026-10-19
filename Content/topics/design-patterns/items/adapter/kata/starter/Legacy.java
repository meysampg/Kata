/** What the rest of the system expects. */
interface Thermometer {
    /** Degrees Celsius, or empty when no reading is available. */
    java.util.OptionalDouble celsius();
}

/**
 * The vendor's sensor driver. It cannot change.
 * poll() returns text such as "F:98.6" or "C:21.5", or "" when the sensor
 * is offline. A script of readings is replayed one per poll; the last repeats.
 */
final class LegacySensor {
    private final String[] script;
    private int polls;

    LegacySensor(String... script) { this.script = script; }

    String poll() {
        String reading = script[Math.min(polls, script.length - 1)];
        polls++;
        return reading;
    }

    int polls() { return polls; }
}
