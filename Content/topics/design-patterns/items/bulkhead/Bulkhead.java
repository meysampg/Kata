import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Semaphore;
import java.util.function.Supplier;

// [[reject
@SuppressWarnings("serial")
class BulkheadFullException extends RuntimeException {
    BulkheadFullException(String name) { super(name + " is full"); }
}
// ]]

// [[bulkhead
final class Bulkhead {
    private final String name;
    private final Semaphore permits;

    Bulkhead(String name, int maxConcurrent) {
        this.name = name;
        this.permits = new Semaphore(maxConcurrent);
    }

    <T> T call(Supplier<T> op) {
        if (!permits.tryAcquire()) throw new BulkheadFullException(name);
        try {
            return op.get();
        } finally {
            permits.release();
        }
    }
}
// ]]

class Main {
    static String attempt(Bulkhead b, Supplier<String> op) {
        try {
            return b.call(op);
        } catch (BulkheadFullException e) {
            return "rejected: " + e.getMessage();
        }
    }

    public static void main(String[] args) throws InterruptedException {
        // [[wiring
        var inventory = new Bulkhead("inventory", 2);
        var payments = new Bulkhead("payments", 2);
        // ]]
        var release = new CountDownLatch(1);
        var entered = new CountDownLatch(2);
        Supplier<String> stuck = () -> {
            entered.countDown();
            try { release.await(); } catch (InterruptedException e) { }
            return "done";
        };
        // [[saturate
        var t1 = Thread.ofVirtual().start(() -> inventory.call(stuck));
        var t2 = Thread.ofVirtual().start(() -> inventory.call(stuck));
        entered.await();
        // ]]
        System.out.println("inventory " + attempt(inventory, () -> "ok"));
        System.out.println("payments " + attempt(payments, () -> "paid"));
        release.countDown();
        t1.join();
        t2.join();
        System.out.println("inventory " + attempt(inventory, () -> "ok"));
    }
}
