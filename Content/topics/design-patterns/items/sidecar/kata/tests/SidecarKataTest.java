import java.lang.reflect.Field;
import java.lang.reflect.Modifier;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.atomic.AtomicInteger;
import kata.*;

class SidecarKataTest {
    static Response call(Handler h, String path, String token) {
        Map<String, String> headers = token == null ? Map.of() : Map.of("token", token);
        return h.handle(new Request(path, headers));
    }

    @Check(id = "allowed-request-reaches-app")
    void allowed() {
        Handler h = Pipeline.build(Set.of("s3cret"), new Telemetry());
        Response res = call(h, "/orders/42", "s3cret");
        Expect.equal(new Response(200, "order:42"), res, "an authorised request");
    }

    @Check(id = "bad-token-denied")
    void denied() {
        Handler h = Pipeline.build(Set.of("s3cret"), new Telemetry());
        Expect.equal(new Response(401, "denied"), call(h, "/orders/9", "wrong"), "a wrong token");
        Expect.equal(new Response(401, "denied"), call(h, "/orders/9", null), "a missing token");
    }

    @Check(id = "access-log")
    void accessLog() {
        Telemetry t = new Telemetry();
        Handler h = Pipeline.build(Set.of("s3cret"), t);
        call(h, "/orders/42", "s3cret");
        call(h, "/orders/9", "wrong");
        call(h, "/orders/7", "s3cret");
        Expect.equal(List.of("/orders/42 200", "/orders/9 401", "/orders/7 200"), t.accessLog,
            "the access log, denied requests included");
    }

    @Check(id = "metrics")
    void metrics() {
        Telemetry t = new Telemetry();
        Handler h = Pipeline.build(Set.of("s3cret"), t);
        call(h, "/orders/1", "s3cret");
        call(h, "/orders/2", "x");
        call(h, "/orders/3", "s3cret");
        Expect.equal(Map.of(200, 2, 401, 1), t.metrics, "status counts");
    }

    @Check(id = "app-holds-no-platform-concerns", kind = Kind.DESIGN)
    void appIsPure() {
        Class<?> app = Types.named("OrderApp");
        Expect.isTrue(Types.fieldsOfType(app, Telemetry.class).isEmpty(),
            "OrderApp still holds a Telemetry; reporting is a platform concern");
        Expect.isTrue(Types.fieldsOfType(app, Set.class).isEmpty(),
            "OrderApp still holds the allowed tokens; authentication is a platform concern");
        var src = Source.type("OrderApp");
        Expect.none(src.mentions("Telemetry"), "OrderApp still mentions Telemetry");
        Expect.none(src.calls("record"), "OrderApp still records access and metrics");
        Expect.none(src.calls("getOrDefault"), "OrderApp still reads the token header");
        Types.constructor(app);   // fails: "OrderApp needs a constructor OrderApp()"
    }

    @Check(id = "sidecar-wraps-a-handler", kind = Kind.DESIGN)
    void sidecarWraps() {
        Class<?> sidecar = Types.named("Sidecar");
        Expect.isTrue(Handler.class.isAssignableFrom(sidecar),
            "Sidecar should implement Handler so callers cannot tell it from the app");
        Field f = Types.onlyFieldOfType(sidecar, Handler.class);
        Expect.isTrue(Modifier.isPrivate(f.getModifiers()) && Modifier.isFinal(f.getModifiers()),
            "Sidecar." + f.getName() + " should be a private final Handler");
        Types.constructor(sidecar, Handler.class, Set.class, Telemetry.class);
    }

    @Check(id = "sidecar-fronts-any-app", kind = Kind.DESIGN)
    void frontsAnyApp() throws Throwable {
        AtomicInteger reached = new AtomicInteger();
        Handler stub = r -> {
            reached.incrementAndGet();
            return new Response(200, "stub");
        };
        Telemetry t = new Telemetry();
        var ctor = Types.constructor(Types.named("Sidecar"), Handler.class, Set.class, Telemetry.class);
        Handler h;
        try {
            h = (Handler) Types.create(ctor, stub, Set.of("k"), t);
            Expect.equal("stub", call(h, "/x", "k").body(),
                "an authorised call to any wrapped handler");
        } catch (ClassCastException e) {
            Expect.fail("Sidecar casts the app it wraps to a concrete "
                + "type; hold and call it as a plain Handler");
            return;
        }
        Expect.equal(401, call(h, "/x", "no").status(), "an unauthorised call");
        Expect.equal(1, reached.get(), "calls that reached the wrapped handler");
        Expect.equal(List.of("/x 200", "/x 401"), t.accessLog, "the sidecar's access log");
    }

    @Check(id = "pipeline-wires-the-sidecar", kind = Kind.DESIGN)
    void pipelineWires() {
        Handler h = Pipeline.build(Set.of("k"), new Telemetry());
        Expect.isTrue(Types.named("Sidecar").isInstance(h),
            "Pipeline.build should return the Sidecar that wraps the app");
    }
}
