import java.util.HashSet;
import java.util.Set;

// The broker delivers at least once: acks get lost, producers publish
// twice. Today every delivery credits the account again.
final class AccountConsumer {
    private final Ledger ledger;
    private final Set<String> processed = new HashSet<>();

    AccountConsumer(Ledger ledger) { this.ledger = ledger; }

    /** True if the deposit was applied, false if it was a duplicate. */
    synchronized boolean handle(Deposit m) {
        if (processed.contains(m.messageId())) {
            return false;
        }
        ledger.credit(m.account(), m.cents());
        processed.add(m.messageId());
        return true;
    }
}
