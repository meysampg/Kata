import java.util.Set;

// Orders business logic, tangled with auth, access logs and metrics.
final class OrderApp implements Handler {
    private final Set<String> tokens;
    private final Telemetry telemetry;

    OrderApp(Set<String> tokens, Telemetry telemetry) {
        this.tokens = tokens;
        this.telemetry = telemetry;
    }

    @Override
    public Response handle(Request request) {
        String token = request.headers().getOrDefault("token", "");
        Response res;
        if (!tokens.contains(token)) {
            res = new Response(401, "denied");
        } else {
            String id = request.path().substring("/orders/".length());
            res = new Response(200, "order:" + id);
        }
        telemetry.record(request.path(), res.status());
        return res;
    }
}

// Callers build the service here. Keep its signature and behaviour.
final class Pipeline {
    private Pipeline() { }

    static Handler build(Set<String> tokens, Telemetry telemetry) {
        return new OrderApp(tokens, telemetry);
    }
}
