import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.util.ArrayList;
import java.util.List;
import kata.*;

class MediatorKataTest {
    static final List<String> WIDGETS = List.of("TextBox", "Checkbox", "Button");

    @Check(id = "starts-disabled")
    void startsDisabled() {
        var form = new SignupForm();
        Expect.isTrue(!form.submit.enabled(), "Submit should start disabled");
        Expect.equal("", form.name.text(), "the name");
        Expect.isTrue(!form.terms.checked(), "terms should start unchecked");
    }

    @Check(id = "needs-name-and-terms")
    void needsNameAndTerms() {
        var form = new SignupForm();
        form.name.type("ann");
        Expect.isTrue(!form.submit.enabled(), "a name alone is not enough");
        form.terms.toggle();
        Expect.isTrue(form.submit.enabled(), "name and terms enable Submit");
        form.name.type("  ");
        Expect.isTrue(!form.submit.enabled(), "a blank name disables Submit");
        form.name.type("ann");
        form.terms.toggle();
        Expect.isTrue(!form.submit.enabled(), "unchecking terms disables Submit");
    }

    @Check(id = "submit-sends-and-resets")
    void submitSendsAndResets() {
        var form = new SignupForm();
        form.name.type("ann");
        form.terms.toggle();
        form.submit.click();
        Expect.equal(List.of("ann"), form.sent(), "what was sent");
        Expect.equal("", form.name.text(), "the name after sending");
        Expect.isTrue(!form.terms.checked(), "terms after sending");
        Expect.isTrue(!form.submit.enabled(), "Submit after sending");
    }

    @Check(id = "disabled-click-ignored")
    void disabledClickIgnored() {
        var form = new SignupForm();
        form.name.type("ann");
        form.submit.click();
        Expect.equal(List.of(), form.sent(), "a click while disabled");
    }

    @Check(id = "can-submit-again")
    void canSubmitAgain() {
        var form = new SignupForm();
        form.name.type("ann");
        form.terms.toggle();
        form.submit.click();
        form.name.type("bo");
        form.terms.toggle();
        form.submit.click();
        Expect.equal(List.of("ann", "bo"), form.sent(), "two submissions");
    }

    @Check(id = "dialog-interface", kind = Kind.DESIGN)
    void dialogInterface() {
        Class<?> dialog = Types.named("Dialog");
        Expect.isTrue(dialog.isInterface(), "Dialog should be an interface");
        Method m = Types.singleAbstractMethod(dialog);
        Expect.equal("changed", m.getName(), "the method name");
        Expect.equal(1, m.getParameterCount(), "changed's parameter count");
    }

    @Check(id = "widgets-know-only-the-dialog", kind = Kind.DESIGN)
    void widgetsKnowOnlyTheDialog() {
        Class<?> dialog = Types.named("Dialog");
        for (String name : WIDGETS) {
            Class<?> widget = Types.named(name);
            Field f = Types.onlyFieldOfType(widget, dialog);
            int mod = f.getModifiers();
            Expect.isTrue(Modifier.isPrivate(mod) && Modifier.isFinal(mod),
                name + "." + f.getName() + " should be private final");
            Types.constructor(widget, dialog);
            for (String other : WIDGETS) {
                Expect.isTrue(Types.fieldsOfType(widget, Types.named(other)).isEmpty(),
                    name + " still holds a " + other);
                if (!other.equals(name)) {
                    Expect.none(Source.type(name).mentions(other),
                        name + " still mentions " + other);
                }
            }
        }
    }

    @Check(id = "widgets-report-to-the-dialog", kind = Kind.DESIGN)
    void widgetsReportToTheDialog() throws Throwable {
        Class<?> dialog = Types.named("Dialog");
        List<Object> seen = new ArrayList<>();
        Object stub = Types.implement(dialog, args -> { seen.add(args[0]); return null; });

        Object box = Types.create(Types.constructor(Types.named("TextBox"), dialog), stub);
        Types.call(Types.method(box.getClass(), "type", String.class), box, "ann");
        Expect.isTrue(seen.contains(box), "TextBox.type should tell the dialog");
        Expect.equal("ann", Types.call(Types.method(box.getClass(), "text"), box), "the text kept by TextBox");

        Object check = Types.create(Types.constructor(Types.named("Checkbox"), dialog), stub);
        Types.call(Types.method(check.getClass(), "toggle"), check);
        Expect.isTrue(seen.contains(check), "Checkbox.toggle should tell the dialog");
        Expect.equal(true, Types.call(Types.method(check.getClass(), "checked"), check), "the state kept by Checkbox");

        Object button = Types.create(Types.constructor(Types.named("Button"), dialog), stub);
        Types.call(Types.method(button.getClass(), "setEnabled", boolean.class), button, true);
        Types.call(Types.method(button.getClass(), "click"), button);
        Expect.isTrue(seen.contains(button), "Button.click should tell the dialog");
    }
}
