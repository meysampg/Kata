import java.time.Duration;
import java.util.Objects;

// [[product
record ServerConfig(String host, int port, Duration timeout, boolean tls) {
    ServerConfig {
        Objects.requireNonNull(host, "host");
        Objects.requireNonNull(timeout, "timeout");
    }

    static Builder builder(String host) { return new Builder(host); }
// ]]

// [[builder
    static final class Builder {
        private final String host;
        private int port = 80;
        private Duration timeout = Duration.ofSeconds(30);
        private boolean tls;

        private Builder(String host) { this.host = host; }

        Builder port(int port) { this.port = port; return this; }
        Builder timeout(Duration t) { this.timeout = t; return this; }
        Builder tls(boolean tls) { this.tls = tls; return this; }
// ]]

// [[build
        ServerConfig build() {
            if (port < 1 || port > 65535) {
                throw new IllegalStateException("port out of range");
            }
            if (tls && port == 80) {
                throw new IllegalStateException("tls on port 80");
            }
            return new ServerConfig(host, port, timeout, tls);
        }
    }
// ]]
}

class Main {
    public static void main(String[] args) {
        // [[client
        var ok = ServerConfig.builder("api.local")
            .port(8443).tls(true).timeout(Duration.ofSeconds(5))
            .build();
        System.out.println(ok);
        // ]]
        // [[reject
        try {
            ServerConfig.builder("api.local").tls(true).build();
        } catch (IllegalStateException e) {
            System.out.println("rejected: " + e.getMessage());
        }
        // ]]
    }
}
