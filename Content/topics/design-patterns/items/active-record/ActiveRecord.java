import java.util.Optional;
import java.util.TreeMap;

final class Account {
    // [[table
    private static final TreeMap<Long, Long> TABLE = new TreeMap<>();
    private static long nextId = 1;

    private Long id;
    private long balance;
    // ]]

    private Account(Long id, long balance) {
        this.id = id;
        this.balance = balance;
    }

    // [[finders
    static Account open(long initial) { return new Account(null, initial); }

    static Optional<Account> find(long id) {
        Long stored = TABLE.get(id);
        return stored == null
            ? Optional.empty()
            : Optional.of(new Account(id, stored));
    }
    // ]]

    // [[behavior
    void withdraw(long amount) {
        if (amount > balance)
            throw new IllegalStateException("insufficient funds");
        balance -= amount;
    }
    // ]]

    // [[persist
    Account save() {
        if (id == null) id = nextId++;
        TABLE.put(id, balance);
        return this;
    }

    void delete() { if (id != null) TABLE.remove(id); }
    // ]]

    Long id() { return id; }
    long balance() { return balance; }
}

class Main {
    public static void main(String[] args) {
        // [[client
        Account created = Account.open(100).save();
        System.out.println("created #" + created.id());

        Account loaded = Account.find(created.id()).orElseThrow();
        loaded.withdraw(30);
        loaded.save();
        long stored = Account.find(1).orElseThrow().balance();
        System.out.println("balance " + stored);

        try {
            loaded.withdraw(500);
        } catch (IllegalStateException e) {
            System.out.println("rejected: " + e.getMessage());
        }
        // ]]
    }
}
