record Deposit(String messageId, String account, long cents) { }

interface Ledger {
    void credit(String account, long cents);
}
