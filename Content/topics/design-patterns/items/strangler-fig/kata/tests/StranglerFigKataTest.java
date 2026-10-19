import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.List;
import kata.*;

class StranglerFigKataTest {
    static final List<String> USERS = List.of("alice", "bob", "carol", "dave", "erin", "frank", "gina", "hank");

    static String half(String user, String path) {
        return Math.floorMod(user.hashCode(), 100) < 50 ? "modern " + path : "legacy " + path;
    }

    @Check(id = "migrated-prefix-goes-modern")
    void fullyMigrated() {
        Site site = new Site();
        for (String u : USERS) {
            Expect.equal("modern /customers/9", site.handle(u, "/customers/9"), "/customers for " + u);
        }
    }

    @Check(id = "partial-rollout-by-user")
    void partial() {
        Site site = new Site();
        for (String u : USERS) {
            Expect.equal(half(u, "/invoices/1"), site.handle(u, "/invoices/1"), "/invoices/1 for " + u);
        }
    }

    @Check(id = "a-user-sticks-to-one-side")
    void sticky() {
        Site site = new Site();
        for (String u : USERS) {
            String first = site.handle(u, "/invoices/1");
            for (int i = 0; i < 3; i++) {
                Expect.equal(first, site.handle(u, "/invoices/1"), "repeat calls for " + u);
            }
        }
    }

    @Check(id = "unmigrated-stays-legacy")
    void unmigrated() {
        Site site = new Site();
        for (String u : USERS) {
            Expect.equal("legacy /reports/q3", site.handle(u, "/reports/q3"), "/reports for " + u);
        }
    }

    @Check(id = "backend-is-one-method", kind = Kind.DESIGN)
    void backendInterface() {
        Class<?> backend = Types.named("Backend");
        Expect.isTrue(backend.isInterface(), "Backend should be an interface");
        var m = Types.singleAbstractMethod(backend);
        Expect.equal("handle", m.getName(), "the method name");
        Expect.equal(List.of(String.class, String.class), List.of(m.getParameterTypes()), "handle's parameters");
        Expect.equal(String.class, m.getReturnType(), "handle's return type");
    }

    @Check(id = "facade-holds-both-systems", kind = Kind.DESIGN)
    void facadeHolds() {
        Class<?> backend = Types.named("Backend");
        Class<?> facade = Types.named("StranglerFacade");
        Expect.isTrue(backend.isAssignableFrom(facade),
            "StranglerFacade should be a Backend, so callers cannot tell it apart");
        Expect.equal(2, Types.fieldsOfType(facade, backend).size(),
            "StranglerFacade should hold exactly two Backends (legacy and modern)");
        Types.constructor(facade, backend, backend);
    }

    @Check(id = "facade-routes-by-rule", kind = Kind.DESIGN)
    void facadeRoutes() throws Throwable {
        Class<?> backend = Types.named("Backend");
        Class<?> facade = Types.named("StranglerFacade");
        List<String> calls = new ArrayList<>();
        Object old = Types.implement(backend, a -> { calls.add("old"); return "old"; });
        Object fresh = Types.implement(backend, a -> { calls.add("new"); return "new"; });
        Object f = Types.create(Types.constructor(facade, backend, backend), old, fresh);
        Method migrate = Types.method(facade, "migrate", String.class, int.class);
        Method handle = Types.method(facade, "handle", String.class, String.class);
        Expect.equal("old", Types.call(handle, f, "u", "/x/1"), "before any rule");
        Object same = Types.call(migrate, f, "/x", 100);
        Expect.isTrue(same == f, "migrate(...) should return the facade so rules chain");
        Expect.equal("new", Types.call(handle, f, "u", "/x/1"), "a prefix migrated at 100");
        Expect.equal("old", Types.call(handle, f, "u", "/y/1"), "a prefix with no rule");
        Types.call(migrate, f, "/z", 0);
        Expect.equal("old", Types.call(handle, f, "u", "/z/1"), "a prefix migrated at 0");
    }

    @Check(id = "site-delegates-to-facade", kind = Kind.DESIGN)
    void siteDelegates() {
        var site = Source.type("Site");
        Expect.isTrue(!site.news("StranglerFacade").isEmpty(), "Site never builds a StranglerFacade");
        Expect.none(site.calls("startsWith"), "Site still routes by path itself");
        Expect.none(site.calls("floorMod"), "Site still buckets users itself");
    }
}
