// The broker delivers at least once: acks get lost, producers publish
// twice. Today every delivery credits the account again.
final class AccountConsumer {
    private final Ledger ledger;

    AccountConsumer(Ledger ledger) { this.ledger = ledger; }

    /** True if the deposit was applied, false if it was a duplicate. */
    boolean handle(Deposit m) {
        ledger.credit(m.account(), m.cents());
        return true;
    }
}
