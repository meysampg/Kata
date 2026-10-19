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
}
