import java.util.HashMap;
import java.util.List;
import java.util.Map;

record Request(String user, String path) {}

record Response(int status, String body) {}

// [[handler
interface Next {
    Response proceed(Request request);
}

@FunctionalInterface
interface Filter {
    Response apply(Request request, Next next);
}
// ]]

// [[link
final class Chains {
    static Next build(List<Filter> filters, Next terminal) {
        Next next = terminal;
        for (int i = filters.size() - 1; i >= 0; i--) {
            Filter filter = filters.get(i);
            Next rest = next;
            next = request -> filter.apply(request, rest);
        }
        return next;
    }
}
// ]]

class Main {
    public static void main(String[] args) {
        // [[filters
        Filter auth = (r, next) -> r.user().isEmpty()
            ? new Response(401, "login") : next.proceed(r);
        Map<String, Integer> seen = new HashMap<>();
        Filter limit = (r, next) -> seen.merge(r.user(), 1, Integer::sum) > 2
            ? new Response(429, "slow down") : next.proceed(r);
        // ]]
        // [[assemble
        Next app = r -> new Response(200, "hello " + r.user());
        Next chain = Chains.build(List.of(auth, limit), app);
        // ]]
        // [[client
        System.out.println(chain.proceed(new Request("", "/home")));
        for (int i = 0; i < 3; i++) {
            System.out.println(chain.proceed(new Request("ann", "/home")));
        }
        // ]]
    }
}
