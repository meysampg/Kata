import java.util.ArrayList;
import java.util.List;
import java.util.Objects;

interface Dialog {
    void changed(Object source);
}

final class TextBox {
    private final Dialog dialog;
    private String text = "";

    TextBox(Dialog dialog) { this.dialog = Objects.requireNonNull(dialog); }

    String text() { return text; }

    void type(String value) {
        text = value;
        dialog.changed(this);
    }

    void clear() { text = ""; }
}

final class Checkbox {
    private final Dialog dialog;
    private boolean checked;

    Checkbox(Dialog dialog) { this.dialog = Objects.requireNonNull(dialog); }

    boolean checked() { return checked; }

    void toggle() {
        checked = !checked;
        dialog.changed(this);
    }

    void uncheck() { checked = false; }
}

final class Button {
    private final Dialog dialog;
    private boolean enabled;

    Button(Dialog dialog) { this.dialog = Objects.requireNonNull(dialog); }

    boolean enabled() { return enabled; }

    void setEnabled(boolean value) { enabled = value; }

    void click() {
        if (enabled) {
            dialog.changed(this);
        }
    }
}

final class SignupForm implements Dialog {
    final TextBox name = new TextBox(this);
    final Checkbox terms = new Checkbox(this);
    final Button submit = new Button(this);
    private final List<String> sent = new ArrayList<>();

    List<String> sent() { return sent; }

    @Override
    public void changed(Object source) {
        if (source == submit) {
            sent.add(name.text());
            name.clear();
            terms.uncheck();
        }
        submit.setEnabled(terms.checked() && !name.text().isBlank());
    }
}
