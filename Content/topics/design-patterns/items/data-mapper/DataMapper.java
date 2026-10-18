import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

// [[domain
record Email(String value) {
    Email {
        if (!value.contains("@")) throw new IllegalArgumentException(value);
    }
}

final class Customer {
    private final long id;
    private final String name;
    private Email email;

    Customer(long id, String name, Email email) {
        this.id = id;
        this.name = name;
        this.email = email;
    }

    long id() { return id; }
    String name() { return name; }
    Email email() { return email; }
    void changeEmail(Email next) { this.email = next; }
    public String toString() { return name + " <" + email.value() + ">"; }
}
// ]]

// [[row
record Row(long id, String name, String emailAddr) {}
// ]]

// [[mapper
final class CustomerMapper {
    private final Map<Long, Row> table;

    CustomerMapper(Map<Long, Row> table) { this.table = table; }

    Optional<Customer> find(long id) {
        return Optional.ofNullable(table.get(id)).map(this::toDomain);
    }

    void save(Customer c) { table.put(c.id(), toRow(c)); }

    private Customer toDomain(Row r) {
        return new Customer(r.id(), r.name(), new Email(r.emailAddr()));
    }

    private Row toRow(Customer c) {
        return new Row(c.id(), c.name(), c.email().value());
    }
}
// ]]

class Main {
    public static void main(String[] args) {
        var table = new HashMap<Long, Row>();
        table.put(1L, new Row(1, "Ada", "ada@old.org"));
        table.put(2L, new Row(2, "Bob", "broken"));
        var mapper = new CustomerMapper(table);
        // [[client
        Customer ada = mapper.find(1).orElseThrow();
        System.out.println(ada);
        ada.changeEmail(new Email("ada@new.org"));
        mapper.save(ada);
        System.out.println(table.get(1L));
        // ]]
        // [[guard
        try {
            mapper.find(2);
        } catch (IllegalArgumentException e) {
            System.out.println("corrupt row: " + e.getMessage());
        }
        // ]]
    }
}
