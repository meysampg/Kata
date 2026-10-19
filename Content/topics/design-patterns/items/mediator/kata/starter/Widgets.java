import java.util.ArrayList;
import java.util.List;

// Sign-up form: Submit is enabled only with a name and accepted terms.
// Every widget knows the others, so every new rule touches all of them.
final class TextBox {
    Button submit;
    Checkbox terms;
    private String text = "";

    String text() { return text; }

    void type(String value) {
        text = value;
        submit.setEnabled(!text.isBlank() && terms.checked());
    }

    void clear() {
        text = "";
        submit.setEnabled(false);
    }
}

final class Checkbox {
    Button submit;
    TextBox name;
    private boolean checked;

    boolean checked() { return checked; }

    void toggle() {
        checked = !checked;
        submit.setEnabled(checked && !name.text().isBlank());
    }

    void uncheck() {
        checked = false;
        submit.setEnabled(false);
    }
}

final class Button {
    TextBox name;
    Checkbox terms;
    List<String> sent;
    private boolean enabled;

    boolean enabled() { return enabled; }

    void setEnabled(boolean value) { enabled = value; }

    void click() {
        if (!enabled) {
            return;
        }
        sent.add(name.text());
        name.clear();
        terms.uncheck();
    }
}

final class SignupForm {
    final TextBox name = new TextBox();
    final Checkbox terms = new Checkbox();
    final Button submit = new Button();
    private final List<String> sent = new ArrayList<>();

    SignupForm() {
        name.submit = submit;
        name.terms = terms;
        terms.submit = submit;
        terms.name = name;
        submit.name = name;
        submit.terms = terms;
        submit.sent = sent;
    }

    List<String> sent() { return sent; }
}
