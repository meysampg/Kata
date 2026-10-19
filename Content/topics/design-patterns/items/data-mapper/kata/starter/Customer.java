// The domain object also knows the table layout. Schema changes hit it.
final class Customer {
    private final long id;
    private final String name;
    private Email email;

    Customer(long id, String name, Email email) {
        this.id = id;
        this.name = name;
        this.email = email;
    }

    static Customer fromRow(Row row) {
        return new Customer(row.id(), row.name(), new Email(row.emailAddr()));
    }

    Row toRow() {
        return new Row(id, name, email.value().toLowerCase());
    }

    long id() { return id; }
    String name() { return name; }
    Email email() { return email; }
    void changeEmail(Email next) { this.email = next; }
}
