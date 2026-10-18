import java.util.Comparator;
import java.util.Map;
import java.util.Set;
import java.util.HashMap;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.TimeUnit;

record Request(String path, String token) {}
record Response(int status, String body) {}

interface Service { Response handle(Request request); }

// [[gateway
final class Gateway {
    private final Map<String, Service> routes = new HashMap<>();
    private final Set<String> tokens;

    Gateway(Set<String> tokens) { this.tokens = tokens; }

    Gateway route(String prefix, Service service) {
        routes.put(prefix, service);
        return this;
    }

    Response handle(Request req) {
        if (!tokens.contains(req.token())) {
            return new Response(401, "unauthorized");
        }
        if (req.path().equals("/home")) return home(req);
        return routes.entrySet().stream()
            .filter(e -> req.path().startsWith(e.getKey()))
            .max(Comparator.comparingInt(e -> e.getKey().length()))
            .map(e -> e.getValue().handle(req))
            .orElse(new Response(404, "no route"));
    }
    // ]]

    // [[aggregate
    private Response home(Request req) {
        var user = CompletableFuture.supplyAsync(
            () -> routes.get("/users").handle(req));
        var orders = CompletableFuture.supplyAsync(
            () -> routes.get("/orders").handle(req))
            .orTimeout(300, TimeUnit.MILLISECONDS)
            .exceptionally(e -> new Response(503, "orders:n/a"));
        return new Response(200,
            user.join().body() + " | " + orders.join().body());
    }
    // ]]
}

class Main {
    public static void main(String[] args) {
        // [[wire
        var gateway = new Gateway(Set.of("t-1"))
            .route("/users", r -> new Response(200, "user:7"))
            .route("/orders", r -> new Response(200, "orders:2"));
        // ]]
        // [[client
        for (var req : new Request[] {
                new Request("/users/7", "t-1"),
                new Request("/home", "t-1"),
                new Request("/orders/7", "bad"),
                new Request("/billing", "t-1")}) {
            var res = gateway.handle(req);
            System.out.println(req.path() + " -> "
                + res.status() + " " + res.body());
        }
        // ]]
    }
}
