import java.util.Set;

final class Sidecar implements Handler {
    private final Handler app;
    private final Set<String> tokens;
    private final Telemetry telemetry;

    Sidecar(Handler app, Set<String> tokens, Telemetry telemetry) {
        this.app = app;
        this.tokens = tokens;
        this.telemetry = telemetry;
    }

    @Override
    public Response handle(Request request) {
        String token = request.headers().getOrDefault("token", "");
        Response res = tokens.contains(token)
            ? app.handle(request)
            : new Response(401, "denied");
        telemetry.record(request.path(), res.status());
        return res;
    }
}
