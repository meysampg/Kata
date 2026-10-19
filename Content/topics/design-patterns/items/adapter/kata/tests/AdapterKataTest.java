import java.lang.reflect.Field;
import java.lang.reflect.Modifier;
import java.util.OptionalDouble;
import kata.*;

class AdapterKataTest {
    static Thermometer over(String... script) {
        return new SensorThermometer(new LegacySensor(script));
    }

    @Check(id = "fahrenheit-is-converted")
    void fahrenheitIsConverted() {
        Expect.equal(100.0, over("F:212").celsius().getAsDouble(), "212 F");
        Expect.equal(0.0, over("F:32.0").celsius().getAsDouble(), "32 F");
        Expect.equal(37.0, Math.round(over("F:98.6").celsius().getAsDouble() * 10) / 10.0, "98.6 F");
    }

    @Check(id = "celsius-passes-through")
    void celsiusPassesThrough() {
        Expect.equal(21.5, over("C:21.5").celsius().getAsDouble(), "21.5 C");
        Expect.equal(-4.0, over("C:-4").celsius().getAsDouble(), "-4 C");
    }

    @Check(id = "offline-is-empty")
    void offlineIsEmpty() {
        Expect.equal(OptionalDouble.empty(), over("").celsius(), "an offline sensor");
    }

    @Check(id = "unknown-unit-is-rejected")
    void unknownUnitIsRejected() {
        Expect.raises(IllegalArgumentException.class,
            () -> over("K:300").celsius(), "a reading in kelvin");
    }

    @Check(id = "one-poll-per-reading")
    void onePollPerReading() {
        LegacySensor sensor = new LegacySensor("C:1");
        Thermometer t = new SensorThermometer(sensor);
        Expect.equal(0, sensor.polls(), "polls before the first reading");
        t.celsius();
        Expect.equal(1, sensor.polls(), "polls after one reading");
        t.celsius();
        Expect.equal(2, sensor.polls(), "polls after two readings");
    }

    @Check(id = "every-reading-is-fresh")
    void everyReadingIsFresh() {
        Thermometer t = over("C:10", "F:50", "", "C:12");
        Expect.equal(10.0, t.celsius().getAsDouble(), "first");
        Expect.equal(10.0, t.celsius().getAsDouble(), "second (50 F)");
        Expect.equal(OptionalDouble.empty(), t.celsius(), "third (offline)");
        Expect.equal(12.0, t.celsius().getAsDouble(), "fourth");
    }

    @Check(id = "adapter-is-a-thermometer", kind = Kind.DESIGN)
    void adapterIsAThermometer() {
        Expect.isTrue(Types.named("Thermometer").isAssignableFrom(Types.named("SensorThermometer")),
            "SensorThermometer should implement Thermometer");
    }

    @Check(id = "adapter-wraps-instead-of-extending", kind = Kind.DESIGN)
    void adapterWrapsInsteadOfExtending() {
        Class<?> adapter = Types.named("SensorThermometer");
        Expect.equal(Object.class, adapter.getSuperclass(),
            "the superclass of SensorThermometer (wrap the sensor, do not extend it)");
        Field f = Types.onlyFieldOfType(adapter, Types.named("LegacySensor"));
        Expect.isTrue(Modifier.isPrivate(f.getModifiers()) && Modifier.isFinal(f.getModifiers()),
            "SensorThermometer." + f.getName() + " should be private final");
        Types.constructor(adapter, Types.named("LegacySensor"));
    }

    @Check(id = "legacy-format-stays-inside", kind = Kind.DESIGN)
    void legacyFormatStaysInside() {
        for (var m : Types.named("SensorThermometer").getDeclaredMethods()) {
            if (!Modifier.isPrivate(m.getModifiers()) && !m.isSynthetic()) {
                Expect.isTrue(m.getReturnType() != String.class,
                    "SensorThermometer." + m.getName() + " leaks the sensor's text format");
            }
        }
        Expect.none(Source.type("Thermometer").mentions("LegacySensor"),
            "Thermometer should not know the legacy sensor");
    }
}
