import java.time.Duration;
import java.util.List;

record Header(String name, String value) { }

record HttpRequest(String method, String uri, List<Header> headers,
                   String body, Duration timeout) {

    // Starts a builder. Never throws: validation belongs to build().
    static Builder builder(String uri) {
        throw new UnsupportedOperationException("TODO");
    }

    static final class Builder {
        private Builder(String uri) { }

        Builder method(String method) {
            throw new UnsupportedOperationException("TODO");
        }

        Builder header(String name, String value) {
            throw new UnsupportedOperationException("TODO");
        }

        Builder body(String body) {
            throw new UnsupportedOperationException("TODO");
        }

        Builder timeout(Duration timeout) {
            throw new UnsupportedOperationException("TODO");
        }

        HttpRequest build() {
            throw new UnsupportedOperationException("TODO");
        }
    }
}
