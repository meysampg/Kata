// The facts of a stock ledger. Read-only.
sealed interface StockEvent permits Received, Picked, Adjusted { }

record Received(int units) implements StockEvent { }

record Picked(int units) implements StockEvent { }

record Adjusted(int delta) implements StockEvent { }

final class VersionConflict extends RuntimeException {
    private static final long serialVersionUID = 1L;

    VersionConflict(String message) { super(message); }
}
