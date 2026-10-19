import java.util.ArrayList;
import java.util.List;

// Model: owns the target temperature and the rules for changing it.
final class Thermostat {
    private final List<ModelListener> listeners = new ArrayList<>();
    private int target;

    Thermostat(int target) {
        this.target = target;
    }

    int target() {
        return target;
    }

    void addListener(ModelListener listener) {
        listeners.add(listener);
    }

    void adjust(int delta) {
        target = Math.max(10, Math.min(30, target + delta));
        for (ModelListener listener : List.copyOf(listeners)) {
            listener.changed(target);
        }
    }
}
