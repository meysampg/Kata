import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;

record Request(String path, Map<String, String> headers) {}
record Response(int status, String body) {}

// [[port
interface Handler { Response handle(Request request); }
// ]]

// [[app
final class OrderApp implements Handler {
    public Response handle(Request request) {
        String id = request.path().substring("/orders/".length());
        return new Response(200, "order:" + id);
    }
}
// ]]

// [[sidecar
final class Sidecar implements Handler {
    private final Handler app;
    private final Set<String> tokens;
    final List<String> accessLog = new ArrayList<>();
    final Map<Integer, Integer> metrics = new TreeMap<>();

    Sidecar(Handler app, Set<String> tokens) {
        this.app = app;
        this.tokens = tokens;
    }

    public Response handle(Request request) {
        String token = request.headers().getOrDefault("token", "");
        Response res = tokens.contains(token)
            ? app.handle(request)
            : new Response(401, "denied");
        accessLog.add(request.path() + " " + res.status());
        metrics.merge(res.status(), 1, Integer::sum);
        return res;
    }
}
// ]]

class Main {
    public static void main(String[] args) {
        // [[deploy
        var sidecar = new Sidecar(new OrderApp(), Set.of("s3cret"));
        // ]]
        // [[traffic
        for (var call : List.of(
                Map.entry("/orders/42", "s3cret"),
                Map.entry("/orders/9", "wrong"),
                Map.entry("/orders/7", "s3cret"))) {
            var req = new Request(call.getKey(),
                Map.of("token", call.getValue()));
            var res = sidecar.handle(req);
            System.out.println(res.status() + " " + res.body());
        }
        // ]]
        System.out.println("log: " + sidecar.accessLog);
        System.out.println("metrics: " + sidecar.metrics);
    }
}
