import java.util.List;
import java.util.Set;

// The single entry point in front of the backend services.
final class Gateway {
    Gateway(Set<String> tokens) {
        throw new UnsupportedOperationException("TODO");
    }

    /** Sends every path that starts with prefix to service. */
    Gateway route(String prefix, Service service) {
        throw new UnsupportedOperationException("TODO");
    }

    /** Answers path itself by calling the routes of these prefixes. */
    Gateway aggregate(String path, List<String> prefixes) {
        throw new UnsupportedOperationException("TODO");
    }

    Response handle(Request request) {
        throw new UnsupportedOperationException("TODO");
    }
}
