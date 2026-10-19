import java.util.Map;
import java.util.Optional;

final class CustomerMapper {
    private final Map<Long, Row> table;

    CustomerMapper(Map<Long, Row> table) {
        this.table = table;
    }

    Optional<Customer> find(long id) {
        return Optional.ofNullable(table.get(id)).map(this::toDomain);
    }

    void save(Customer customer) {
        table.put(customer.id(), toRow(customer));
    }

    private Customer toDomain(Row row) {
        return new Customer(row.id(), row.name(), new Email(row.emailAddr()));
    }

    private Row toRow(Customer customer) {
        return new Row(customer.id(), customer.name(),
            customer.email().value().toLowerCase());
    }
}
