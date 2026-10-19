import java.lang.reflect.Modifier;
import java.util.ArrayList;
import java.util.List;
import kata.*;

class MvcKataTest {
    @Check(id = "model-clamps")
    void modelClamps() {
        Thermostat t = new Thermostat(29);
        t.adjust(5);
        Expect.equal(30, t.target(), "target after +5 from 29");
        t.adjust(-100);
        Expect.equal(10, t.target(), "target after -100");
        t.adjust(3);
        Expect.equal(13, t.target(), "target after +3");
    }

    @Check(id = "model-notifies")
    void modelNotifies() {
        Thermostat t = new Thermostat(20);
        List<Integer> a = new ArrayList<>();
        List<Integer> b = new ArrayList<>();
        t.addListener(a::add);
        t.addListener(b::add);
        t.adjust(1);
        t.adjust(20);
        t.adjust(1);
        Expect.equal(List.of(21, 30, 30), a, "first listener saw");
        Expect.equal(List.of(21, 30, 30), b, "second listener saw");
    }

    @Check(id = "view-renders")
    void viewRenders() {
        List<String> out = new ArrayList<>();
        new TextView(out::add).changed(23);
        Expect.equal(List.of("Target: 23C"), out, "what the view shows");
    }

    @Check(id = "controller-drives-model")
    void controllerDrivesModel() {
        Thermostat t = new Thermostat(29);
        List<String> messages = new ArrayList<>();
        Controller c = new Controller(t, messages::add);
        c.onInput("up");
        c.onInput("up");
        c.onInput("down");
        Expect.equal(29, t.target(), "target after up, up, down from 29");
        Expect.equal(List.of(), messages, "messages for valid commands");
        c.onInput("sing");
        Expect.equal(List.of("Unknown: sing"), messages, "message for an unknown command");
        Expect.equal(29, t.target(), "target after an unknown command");
    }

    @Check(id = "full-loop")
    void fullLoop() {
        List<String> screen = new ArrayList<>();
        Thermostat t = new Thermostat(29);
        t.addListener(new TextView(screen::add));
        Controller c = new Controller(t, screen::add);
        for (String input : List.of("up", "up", "down", "sing")) {
            c.onInput(input);
        }
        Expect.equal(List.of("Target: 30C", "Target: 30C", "Target: 29C", "Unknown: sing"), screen,
            "the screen");
    }

    @Check(id = "model-knows-no-view", kind = Kind.DESIGN)
    void modelKnowsNoView() {
        var model = Source.type("Thermostat");
        Expect.none(model.mentions("TextView"), "Thermostat refers to the view");
        Expect.none(model.mentions("Controller"), "Thermostat refers to the controller");
        Expect.none(model.mentions("Consumer"), "Thermostat prints or displays on its own");
        Expect.none(model.mentions("System"), "Thermostat prints or displays on its own");
    }

    @Check(id = "view-only-observes", kind = Kind.DESIGN)
    void viewOnlyObserves() {
        Expect.isTrue(ModelListener.class.isAssignableFrom(Types.named("TextView")),
            "TextView should implement ModelListener");
        var view = Source.type("TextView");
        Expect.none(view.mentions("Thermostat"), "TextView holds the model");
        Expect.none(view.calls("adjust"), "TextView changes the model");
        Expect.none(view.mentions("Controller"), "TextView refers to the controller");
    }

    @Check(id = "controller-does-not-render", kind = Kind.DESIGN)
    void controllerDoesNotRender() {
        var controller = Source.type("Controller");
        Expect.none(controller.mentions("TextView"), "Controller refers to the view");
        Expect.none(controller.mentions("System"), "Controller prints directly");
        Expect.none(controller.calls("target"), "Controller reads model state to decide the output");
        Expect.isTrue(Types.fieldsOfType(Types.named("Controller"), Types.named("Thermostat"))
            .stream().allMatch(f -> Modifier.isFinal(f.getModifiers())),
            "Controller's model field should be final");
    }
}
