import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Future;
import java.util.concurrent.TimeoutException;

interface Remote {
    String call() throws Exception;
}

// Checkout asks the price service through this gateway. When the
// service hangs, so does every request thread that reaches it.
final class Gateway {
    private final ExecutorService pool;

    Gateway(ExecutorService pool) { this.pool = pool; }

    String fetch(Remote remote, long timeoutMs)
            throws InterruptedException, ExecutionException,
                   TimeoutException {
        Future<String> result = pool.submit(remote::call);
        return result.get();
    }
}
