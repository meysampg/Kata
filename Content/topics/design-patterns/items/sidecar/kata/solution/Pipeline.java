import java.util.Set;

final class Pipeline {
    private Pipeline() { }

    static Handler build(Set<String> tokens, Telemetry telemetry) {
        return new Sidecar(new OrderApp(), tokens, telemetry);
    }
}
