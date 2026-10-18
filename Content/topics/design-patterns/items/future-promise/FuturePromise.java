import java.util.concurrent.CompletableFuture;
import java.util.concurrent.Executor;
import java.util.concurrent.Executors;

class Main {
    // [[source
    static CompletableFuture<String> userName(Executor io, int id) {
        return CompletableFuture.supplyAsync(() -> {
            if (id <= 0) throw new IllegalArgumentException("no user " + id);
            return "user-" + id;
        }, io);
    }

    static CompletableFuture<Integer> balance(Executor io, String user) {
        return CompletableFuture.supplyAsync(() -> user.length() * 6, io);
    }
    // ]]

    public static void main(String[] args) throws Exception {
        try (var io = Executors.newVirtualThreadPerTaskExecutor()) {
            // [[compose
            var owed = userName(io, 7)
                .thenCompose(u -> balance(io, u)
                    .thenApply(b -> u + " owes " + b));
            var both = userName(io, 3)
                .thenCombine(userName(io, 4), (a, b) -> a + "+" + b);
            System.out.println(owed.get());
            System.out.println(both.get());
            // ]]
            // [[failure
            var safe = userName(io, 0)
                .thenCompose(u -> balance(io, u))
                .handle((value, error) -> error == null
                    ? "ok " + value
                    : "fallback: " + error.getCause().getMessage());
            System.out.println(safe.get());
            // ]]
        }
        // [[promise
        var promise = new CompletableFuture<Integer>();
        var doubled = promise.thenApply(x -> x * 2);
        promise.complete(21);
        System.out.println("promise: " + doubled.get());
        // ]]
    }
}
