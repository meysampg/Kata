import java.util.function.Supplier;

interface Documents {
    String read(String id);
}

// Opening a connection is slow; reading over it is slow too.
final class RemoteDocuments implements Documents {
    RemoteDocuments() { /* connect */ }

    public String read(String id) { return "body of " + id; }
}

// TODO: a stand-in for any Documents that connects only when first needed
// and never reads the same id twice.
final class CachedDocuments implements Documents {
    CachedDocuments(Supplier<Documents> factory) {
        throw new UnsupportedOperationException("TODO");
    }

    public String read(String id) {
        throw new UnsupportedOperationException("TODO");
    }
}
