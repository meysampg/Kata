import java.util.function.Consumer;

// View: shows the target to whoever listens on `out`.
final class TextView implements ModelListener {
    private final Consumer<String> out;

    TextView(Consumer<String> out) {
        this.out = out;
    }

    public void changed(int target) {
        out.accept("Target: " + target + "C");
    }
}
