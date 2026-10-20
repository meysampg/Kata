import java.lang.reflect.Constructor;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.time.Duration;
import java.util.List;
import kata.*;

class BuilderKataTest {
    static HttpRequest.Builder base() {
        return HttpRequest.builder("https://api.local/items");
    }

    @Check(id = "defaults")
    void defaults() {
        HttpRequest r = base().build();
        Expect.equal("GET", r.method(), "default method");
        Expect.equal("https://api.local/items", r.uri(), "uri");
        Expect.equal(Duration.ofSeconds(30), r.timeout(), "default timeout");
        Expect.equal(List.of(), r.headers(), "default headers");
        Expect.equal(null, r.body(), "default body");
    }

    @Check(id = "fluent-chain")
    void fluentChain() {
        HttpRequest r = base().method("POST").body("{}")
            .timeout(Duration.ofSeconds(5)).header("X", "1").build();
        Expect.equal("POST", r.method(), "method");
        Expect.equal("{}", r.body(), "body");
        Expect.equal(Duration.ofSeconds(5), r.timeout(), "timeout");
        Expect.equal(List.of(new Header("X", "1")), r.headers(), "headers");
    }

    @Check(id = "headers-keep-order-and-repeats")
    void headersKeepOrderAndRepeats() {
        HttpRequest r = base().header("B", "2").header("A", "1")
            .header("B", "3").build();
        Expect.equal(List.of(new Header("B", "2"), new Header("A", "1"),
            new Header("B", "3")), r.headers(), "headers in call order");
    }

    @Check(id = "rejects-get-with-body")
    void rejectsGetWithBody() {
        Expect.raises(IllegalStateException.class,
            () -> base().body("x").build(), "a GET with a body");
        base().method("PUT").body("x").build();
    }

    @Check(id = "rejects-bad-timeout")
    void rejectsBadTimeout() {
        Expect.raises(IllegalStateException.class,
            () -> base().timeout(Duration.ZERO).build(), "a zero timeout");
        Expect.raises(IllegalStateException.class,
            () -> base().timeout(Duration.ofSeconds(-1)).build(), "a negative timeout");
    }

    @Check(id = "rejects-blank-uri")
    void rejectsBlankUri() {
        Expect.raises(IllegalStateException.class,
            () -> HttpRequest.builder("  ").build(), "a blank uri");
    }

    @Check(id = "builder-reusable")
    void builderReusable() {
        HttpRequest.Builder b = base().header("A", "1");
        HttpRequest first = b.build();
        HttpRequest second = b.build();
        Expect.equal(first, second, "two builds from the same builder");
        b.header("B", "2");
        Expect.equal(1, first.headers().size(), "the first product after the builder moved on");
    }

    @Check(id = "product-immutable", kind = Kind.DESIGN)
    void productImmutable() {
        for (Field f : HttpRequest.class.getDeclaredFields()) {
            if (Modifier.isStatic(f.getModifiers()) || f.isSynthetic()) continue;
            int m = f.getModifiers();
            Expect.isTrue(Modifier.isPrivate(m) && Modifier.isFinal(m),
                "HttpRequest." + f.getName() + " should be private final");
        }
        List<Header> headers = base().header("A", "1").build().headers();
        Expect.raises(UnsupportedOperationException.class,
            () -> headers.add(new Header("B", "2")), "adding to HttpRequest.headers()");
    }

    @Check(id = "defensive-copy", kind = Kind.DESIGN)
    void defensiveCopy() {
        HttpRequest.Builder b = base().header("A", "1");
        HttpRequest r = b.build();
        b.header("B", "2").method("POST").body("x");
        Expect.equal(List.of(new Header("A", "1")), r.headers(), "headers after the builder changed");
        Expect.equal("GET", r.method(), "method after the builder changed");
        Expect.equal(null, r.body(), "body after the builder changed");
    }

    @Check(id = "fluent-returns-builder", kind = Kind.DESIGN)
    void fluentReturnsBuilder() {
        Class<?> builder = HttpRequest.Builder.class;
        Expect.equal(builder, Types.method(builder, "method", String.class).getReturnType(),
            "the return type of Builder.method (so calls can chain)");
        Expect.equal(builder, Types.method(builder, "header", String.class, String.class)
            .getReturnType(), "the return type of Builder.header (so calls can chain)");
        Expect.equal(builder, Types.method(builder, "body", String.class).getReturnType(),
            "the return type of Builder.body (so calls can chain)");
        Expect.equal(builder, Types.method(builder, "timeout", Duration.class).getReturnType(),
            "the return type of Builder.timeout (so calls can chain)");
        Expect.equal(HttpRequest.class, Types.method(builder, "build").getReturnType(),
            "the return type of build()");
    }

    @Check(id = "no-telescoping-constructor", kind = Kind.DESIGN)
    void noTelescopingConstructor() {
        for (Constructor<?> c : HttpRequest.class.getDeclaredConstructors()) {
            if (!Modifier.isPrivate(c.getModifiers())) {
                Expect.equal(5, c.getParameterCount(),
                    "parameters of a non-private HttpRequest constructor (only the canonical one is allowed)");
            }
        }
        for (Constructor<?> c : HttpRequest.Builder.class.getDeclaredConstructors()) {
            Expect.isTrue(Modifier.isPrivate(c.getModifiers()),
                "Builder's constructor should be private: start from HttpRequest.builder(uri)");
        }
    }
}
