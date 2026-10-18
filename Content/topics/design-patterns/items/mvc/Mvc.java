import java.util.ArrayList;
import java.util.List;

// [[model
interface ModelListener {
    void changed(int target);
}

final class Thermostat {
    private final List<ModelListener> listeners = new ArrayList<>();
    private int target;

    Thermostat(int target) { this.target = target; }

    void addListener(ModelListener l) { listeners.add(l); }

    void adjust(int delta) {
        target = Math.max(10, Math.min(30, target + delta));
        listeners.forEach(l -> l.changed(target));
    }
}
// ]]

// [[view
final class ConsoleView implements ModelListener {
    public void changed(int target) {
        System.out.println("Target: " + target + "C");
    }
}
// ]]

// [[controller
final class Controller {
    private final Thermostat model;

    Controller(Thermostat model) { this.model = model; }

    void onInput(String command) {
        switch (command) {
            case "up" -> model.adjust(1);
            case "down" -> model.adjust(-1);
            default -> System.out.println("Unknown: " + command);
        }
    }
}
// ]]

class Main {
    public static void main(String[] args) {
        // [[wiring
        var model = new Thermostat(29);
        model.addListener(new ConsoleView());
        var controller = new Controller(model);
        // ]]
        for (String input : List.of("up", "up", "down", "sing")) {
            controller.onInput(input);
        }
    }
}
