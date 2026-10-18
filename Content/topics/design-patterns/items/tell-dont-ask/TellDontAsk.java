// [[before
final class AccountBefore {
    private long balance;
    long getBalance() { return balance; }
    void setBalance(long b) { balance = b; }
}

final class TellerBefore {
    boolean withdraw(AccountBefore a, long amount) {
        if (a.getBalance() >= amount) {       // asks, decides, mutates
            a.setBalance(a.getBalance() - amount);
            return true;
        }
        return false;
    }
}
// ]]

// [[after
final class Account {
    private final long overdraft;
    private long balance;

    Account(long balance, long overdraft) {
        this.balance = balance;
        this.overdraft = overdraft;
    }

    void withdraw(long amount) {             // the rule lives with the data
        if (amount > balance + overdraft)
            throw new IllegalStateException("insufficient funds");
        balance -= amount;
    }
    String statement() { return "balance " + balance; }
}
// ]]

class Main {
    public static void main(String[] args) {
        var old = new AccountBefore();
        old.setBalance(100);
        System.out.println("before: " + new TellerBefore().withdraw(old, 150));

        // [[client
        var account = new Account(100, 50);
        account.withdraw(150);                // tell, don't ask
        System.out.println(account.statement());
        try {
            account.withdraw(1);
        } catch (IllegalStateException e) {
            System.out.println("rejected: " + e.getMessage());
        }
        // ]]
    }
}
