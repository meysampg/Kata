import java.util.function.Consumer;

// Controller: turns user input into calls on the model.
final class Controller {
    private final Thermostat model;
    private final Consumer<String> messages;

    Controller(Thermostat model, Consumer<String> messages) {
        this.model = model;
        this.messages = messages;
    }

    void onInput(String command) {
        switch (command) {
            case "up" -> model.adjust(1);
            case "down" -> model.adjust(-1);
            default -> messages.accept("Unknown: " + command);
        }
    }
}
