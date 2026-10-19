import java.util.concurrent.CompletableFuture;
import java.util.concurrent.Executor;

final class Billing {
    private final Executor io;

    Billing(Executor io) {
        this.io = io;
    }

    CompletableFuture<String> userName(int id) {
        return CompletableFuture.supplyAsync(() -> {
            if (id <= 0) {
                throw new IllegalArgumentException("no user " + id);
            }
            return "user-" + id;
        }, io);
    }

    CompletableFuture<Integer> balance(String user) {
        return CompletableFuture.supplyAsync(() -> user.length() * 6, io);
    }

    CompletableFuture<String> summary(int id) {
        return userName(id).thenCompose(user ->
            balance(user).thenApply(owed -> user + " owes " + owed));
    }

    CompletableFuture<String> pair(int a, int b) {
        return userName(a).thenCombine(userName(b), (x, y) -> x + "+" + y);
    }

    CompletableFuture<String> summaryOrFallback(int id) {
        return summary(id).exceptionally(error -> {
            Throwable cause = error;
            while (cause.getCause() != null) {
                cause = cause.getCause();
            }
            return "fallback: " + cause.getMessage();
        });
    }
}
