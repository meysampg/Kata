import java.util.List;
import java.util.Map;

// Tracks what a business transaction touched and writes it once, in order.
final class UnitOfWork {
    UnitOfWork(Map<String, Integer> db) {
        throw new UnsupportedOperationException("TODO");
    }

    Account load(String id) {
        throw new UnsupportedOperationException("TODO");
    }

    void registerNew(Account account) {
        throw new UnsupportedOperationException("TODO");
    }

    void registerRemoved(Account account) {
        throw new UnsupportedOperationException("TODO");
    }

    List<String> commit() {
        throw new UnsupportedOperationException("TODO");
    }

    void rollback() {
        throw new UnsupportedOperationException("TODO");
    }
}
