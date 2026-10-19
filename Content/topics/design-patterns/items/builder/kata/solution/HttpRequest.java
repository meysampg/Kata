import java.time.Duration;
import java.util.ArrayList;
import java.util.List;

record Header(String name, String value) { }

record HttpRequest(String method, String uri, List<Header> headers,
                   String body, Duration timeout) {
    HttpRequest {
        headers = List.copyOf(headers);
    }

    static Builder builder(String uri) { return new Builder(uri); }

    static final class Builder {
        private final String uri;
        private String method = "GET";
        private final List<Header> headers = new ArrayList<>();
        private String body;
        private Duration timeout = Duration.ofSeconds(30);

        private Builder(String uri) { this.uri = uri; }

        Builder method(String method) { this.method = method; return this; }

        Builder header(String name, String value) {
            headers.add(new Header(name, value));
            return this;
        }

        Builder body(String body) { this.body = body; return this; }

        Builder timeout(Duration timeout) {
            this.timeout = timeout;
            return this;
        }

        HttpRequest build() {
            if (uri == null || uri.isBlank()) {
                throw new IllegalStateException("blank uri");
            }
            if (timeout == null || timeout.isZero() || timeout.isNegative()) {
                throw new IllegalStateException("timeout must be positive");
            }
            if (method.equals("GET") && body != null) {
                throw new IllegalStateException("GET with a body");
            }
            return new HttpRequest(method, uri, headers, body, timeout);
        }
    }
}
