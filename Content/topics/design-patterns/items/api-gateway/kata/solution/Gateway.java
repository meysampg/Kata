import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

final class Gateway {
    private final Set<String> tokens;
    private final Map<String, Service> routes = new HashMap<>();
    private final Map<String, List<String>> aggregates = new HashMap<>();

    Gateway(Set<String> tokens) {
        this.tokens = Set.copyOf(tokens);
    }

    Gateway route(String prefix, Service service) {
        routes.put(prefix, service);
        return this;
    }

    Gateway aggregate(String path, List<String> prefixes) {
        aggregates.put(path, List.copyOf(prefixes));
        return this;
    }

    Response handle(Request request) {
        if (request.token() == null || !tokens.contains(request.token())) {
            return new Response(401, "unauthorized");
        }
        List<String> parts = aggregates.get(request.path());
        if (parts != null) {
            return combine(request, parts);
        }
        String best = null;
        for (String prefix : routes.keySet()) {
            if (request.path().startsWith(prefix)
                    && (best == null || prefix.length() > best.length())) {
                best = prefix;
            }
        }
        return best == null
            ? new Response(404, "no route")
            : routes.get(best).handle(request);
    }

    private Response combine(Request request, List<String> prefixes) {
        List<String> bodies = new ArrayList<>();
        for (String prefix : prefixes) {
            bodies.add(call(prefix, request));
        }
        return new Response(200, String.join(" | ", bodies));
    }

    private String call(String prefix, Request request) {
        Service service = routes.get(prefix);
        if (service == null) {
            return prefix + ":n/a";
        }
        try {
            Response res = service.handle(request);
            return res.status() >= 500 ? prefix + ":n/a" : res.body();
        } catch (RuntimeException e) {
            return prefix + ":n/a";
        }
    }
}
