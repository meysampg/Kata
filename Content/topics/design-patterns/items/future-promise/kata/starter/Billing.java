import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CompletionException;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.Executor;

// Every pipeline below parks a pool thread on get() while it waits.
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
        return CompletableFuture.supplyAsync(() -> {
            try {
                String user = userName(id).get();
                int owed = balance(user).get();
                return user + " owes " + owed;
            } catch (ExecutionException | InterruptedException e) {
                throw new CompletionException(e.getCause());
            }
        }, io);
    }

    CompletableFuture<String> pair(int a, int b) {
        return CompletableFuture.supplyAsync(() -> {
            try {
                return userName(a).get() + "+" + userName(b).get();
            } catch (ExecutionException | InterruptedException e) {
                throw new CompletionException(e.getCause());
            }
        }, io);
    }

    CompletableFuture<String> summaryOrFallback(int id) {
        return CompletableFuture.supplyAsync(() -> {
            try {
                return summary(id).get();
            } catch (ExecutionException | InterruptedException e) {
                Throwable cause = e;
                while (cause.getCause() != null) {
                    cause = cause.getCause();
                }
                return "fallback: " + cause.getMessage();
            }
        }, io);
    }
}
