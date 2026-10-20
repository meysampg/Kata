import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;
import kata.*;

class ProxyKataTest {
    /** A Documents that counts how often it is built and read. */
    static final class Counting implements Documents {
        final AtomicInteger built;
        final AtomicInteger reads = new AtomicInteger();
        boolean failNext;

        Counting(AtomicInteger built) { this.built = built; built.incrementAndGet(); }

        public String read(String id) {
            reads.incrementAndGet();
            if (failNext) { failNext = false; throw new IllegalStateException("down"); }
            Stress.pause(2);
            return "body of " + id;
        }
    }

    @Check(id = "nothing-built-before-first-read")
    void nothingBuiltBeforeFirstRead() {
        var built = new AtomicInteger();
        new CachedDocuments(() -> new Counting(built));
        Expect.equal(0, built.get(), "real Documents built just by creating the proxy");
    }

    @Check(id = "built-once")
    void builtOnce() {
        var built = new AtomicInteger();
        var docs = new CachedDocuments(() -> new Counting(built));
        docs.read("a");
        docs.read("b");
        docs.read("c");
        Expect.equal(1, built.get(), "real Documents built after three reads");
    }

    @Check(id = "same-id-read-once")
    void sameIdReadOnce() {
        var built = new AtomicInteger();
        Counting[] real = new Counting[1];
        var docs = new CachedDocuments(() -> real[0] = new Counting(built));
        Expect.equal("body of a", docs.read("a"), "first read");
        Expect.equal("body of a", docs.read("a"), "second read");
        Expect.equal(1, real[0].reads.get(), "real reads of the same id");
        docs.read("b");
        Expect.equal(2, real[0].reads.get(), "a different id must reach the real thing");
    }

    @Check(id = "failures-are-not-cached")
    void failuresAreNotCached() {
        var built = new AtomicInteger();
        Counting[] real = new Counting[1];
        var docs = new CachedDocuments(() -> real[0] = new Counting(built));
        docs.read("warm");
        real[0].failNext = true;
        Expect.raises(IllegalStateException.class, () -> docs.read("x"), "a failing read");
        Expect.equal("body of x", docs.read("x"), "retrying after a failure");
    }

    @Check(id = "concurrent-first-reads", timeoutMs = 5000)
    void concurrentFirstReads() {
        var built = new AtomicInteger();
        Counting[] real = new Counting[1];
        var docs = new CachedDocuments(() -> {
            Stress.pause(10);
            return real[0] = new Counting(built);
        });
        List<String> bodies = Stress.race(8, () -> docs.read("shared"));
        Expect.equal(1, built.get(), "real Documents built by 8 simultaneous first reads");
        Expect.equal(1, real[0].reads.get(), "real reads of one id by 8 threads");
        Expect.equal(8, (int) bodies.stream().filter("body of shared"::equals).count(), "replies");
    }

    @Check(id = "proxy-is-a-documents", kind = Kind.DESIGN)
    void proxyIsADocuments() {
        Class<?> proxy = Types.named("CachedDocuments");
        Expect.isTrue(Documents.class.isAssignableFrom(proxy),
            "CachedDocuments should implement Documents so callers cannot tell");
        Types.constructor(proxy, java.util.function.Supplier.class);
    }

    @Check(id = "proxy-does-not-hardwire-the-real-one", kind = Kind.DESIGN)
    void proxyDoesNotHardwireTheRealOne() {
        var proxy = Source.type("CachedDocuments");
        Expect.none(proxy.mentions("RemoteDocuments"),
            "CachedDocuments names RemoteDocuments; get the real Documents from the factory");
        Expect.none(proxy.instanceofs(), "CachedDocuments inspects the concrete type of the subject");
    }
}
