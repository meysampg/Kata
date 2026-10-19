import java.util.ArrayList;
import java.util.List;

// Model: owns the target temperature and the rules for changing it.
final class Thermostat {
    private final List<ModelListener> listeners = new ArrayList<>();
    private int target;

    Thermostat(int target) {
        throw new UnsupportedOperationException("TODO");
    }

    int target() {
        throw new UnsupportedOperationException("TODO");
    }

    void addListener(ModelListener listener) {
        throw new UnsupportedOperationException("TODO");
    }

    void adjust(int delta) {
        throw new UnsupportedOperationException("TODO");
    }
}
