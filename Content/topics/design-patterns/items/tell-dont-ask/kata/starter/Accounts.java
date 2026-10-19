// Teller asks for the data, decides, then writes the result back.
final class Account {
    private final long overdraft;
    private long balance;

    Account(long balance, long overdraft) {
        this.balance = balance;
        this.overdraft = overdraft;
    }

    long getBalance() { return balance; }
    void setBalance(long balance) { this.balance = balance; }
    long getOverdraft() { return overdraft; }
}

final class Teller {
    boolean withdraw(Account a, long amount) {
        if (a.getBalance() + a.getOverdraft() >= amount) {
            a.setBalance(a.getBalance() - amount);
            return true;
        }
        return false;
    }

    boolean transfer(Account from, Account to, long amount) {
        if (withdraw(from, amount)) {
            to.setBalance(to.getBalance() + amount);
            return true;
        }
        return false;
    }
}
