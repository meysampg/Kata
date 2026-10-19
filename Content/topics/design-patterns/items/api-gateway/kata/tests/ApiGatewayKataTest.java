import java.util.List;
import java.util.Set;
import java.util.concurrent.atomic.AtomicInteger;
import kata.*;

class ApiGatewayKataTest {
    static Service says(String body) {
        return r -> new Response(200, body);
    }

    static Gateway gateway() {
        return new Gateway(Set.of("t-1", "t-2"));
    }

    static String call(Gateway g, String path, String token) {
        Response res = g.handle(new Request(path, token));
        return res.status() + " " + res.body();
    }

    @Check(id = "forwards-to-route")
    void forwards() {
        Gateway g = gateway().route("/users", says("user:7")).route("/orders", says("orders:2"));
        Expect.equal("200 user:7", call(g, "/users/7", "t-1"), "/users/7");
        Expect.equal("200 orders:2", call(g, "/orders", "t-2"), "/orders");
    }

    @Check(id = "service-receives-request")
    void serviceReceivesRequest() {
        Gateway g = gateway().route("/echo", r -> new Response(200, r.path() + "@" + r.token()));
        Expect.equal("200 /echo/1@t-1", call(g, "/echo/1", "t-1"), "the request seen by the service");
    }

    @Check(id = "longest-prefix-wins")
    void longestPrefixWins() {
        Gateway a = gateway().route("/users", says("users"))
            .route("/users/admin", says("admin")).route("/", says("root"));
        Gateway b = gateway().route("/", says("root"))
            .route("/users/admin", says("admin")).route("/users", says("users"));
        for (Gateway g : List.of(a, b)) {
            Expect.equal("200 admin", call(g, "/users/admin/3", "t-1"), "/users/admin/3");
            Expect.equal("200 users", call(g, "/users/9", "t-1"), "/users/9");
            Expect.equal("200 root", call(g, "/health", "t-1"), "/health");
        }
    }

    @Check(id = "unknown-path-is-404")
    void unknownIs404() {
        Gateway g = gateway().route("/users", says("u"));
        Expect.equal("404 no route", call(g, "/billing", "t-1"), "an unrouted path");
    }

    @Check(id = "auth-first")
    void authFirst() {
        AtomicInteger calls = new AtomicInteger();
        Gateway g = gateway().route("/users", r -> {
            calls.incrementAndGet();
            return new Response(200, "u");
        });
        Expect.equal("401 unauthorized", call(g, "/users/1", "bad"), "a wrong token");
        Expect.equal("401 unauthorized", call(g, "/users/1", null), "a missing token");
        Expect.equal("401 unauthorized", call(g, "/billing", "bad"), "a wrong token on an unrouted path");
        Expect.equal(0, calls.get(), "calls that reached the service");
    }

    @Check(id = "aggregate-joins-in-order")
    void aggregateJoins() {
        Gateway g = gateway().route("/users", says("user:7")).route("/orders", says("orders:2"))
            .aggregate("/home", List.of("/users", "/orders"));
        Expect.equal("200 user:7 | orders:2", call(g, "/home", "t-1"), "/home");
    }

    @Check(id = "aggregate-degrades")
    void aggregateDegrades() {
        Gateway g = gateway().route("/users", says("user:7"))
            .route("/orders", r -> { throw new IllegalStateException("down"); })
            .route("/promos", r -> new Response(503, "busy"))
            .aggregate("/home", List.of("/users", "/orders", "/promos", "/ghost"));
        Expect.equal("200 user:7 | /orders:n/a | /promos:n/a | /ghost:n/a", call(g, "/home", "t-1"),
            "/home with failing backends");
    }

    @Check(id = "aggregate-needs-auth")
    void aggregateNeedsAuth() {
        Gateway g = gateway().route("/users", says("u")).aggregate("/home", List.of("/users"));
        Expect.equal("401 unauthorized", call(g, "/home", "bad"), "/home with a bad token");
    }

    @Check(id = "api-shape", kind = Kind.DESIGN)
    void apiShape() {
        Class<?> gw = Types.named("Gateway");
        Types.constructor(gw, Set.class);
        Expect.equal(gw, Types.method(gw, "route", String.class, Service.class).getReturnType(),
            "route(...) should return the Gateway so calls chain");
        Expect.equal(gw, Types.method(gw, "aggregate", String.class, List.class).getReturnType(),
            "aggregate(...) should return the Gateway so calls chain");
    }

    @Check(id = "routes-are-data", kind = Kind.DESIGN)
    void routesAreData() {
        var gw = Source.type("Gateway");
        Expect.none(gw.comparedStrings(),
            "Gateway compares against string literals; routes belong in route(...) calls");
        Expect.none(gw.switches(), "Gateway switches on the path");
    }

    @Check(id = "gateway-names-no-service", kind = Kind.DESIGN)
    void namesNoService() {
        Expect.isTrue(Types.fieldsOfType(Types.named("Gateway"), Service.class).isEmpty(),
            "Gateway keeps a fixed Service field; hold routes in a collection instead");
    }
}
