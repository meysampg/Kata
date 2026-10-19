final class Account {
    private final long overdraft;
    private long balance;

    Account(long balance, long overdraft) {
        this.balance = balance;
        this.overdraft = overdraft;
    }

    long getBalance() { return balance; }

    boolean withdraw(long amount) {
        if (amount > balance + overdraft) {
            return false;
        }
        balance -= amount;
        return true;
    }

    void deposit(long amount) { balance += amount; }
}

final class Teller {
    boolean withdraw(Account a, long amount) {
        return a.withdraw(amount);
    }

    boolean transfer(Account from, Account to, long amount) {
        if (from.withdraw(amount)) {
            to.deposit(amount);
            return true;
        }
        return false;
    }
}
