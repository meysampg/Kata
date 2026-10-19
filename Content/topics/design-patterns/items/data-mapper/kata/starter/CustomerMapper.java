import java.util.Map;
import java.util.Optional;

final class CustomerMapper {
    private final Map<Long, Row> table;

    CustomerMapper(Map<Long, Row> table) {
        this.table = table;
    }

    Optional<Customer> find(long id) {
        return Optional.ofNullable(table.get(id)).map(Customer::fromRow);
    }

    void save(Customer customer) {
        table.put(customer.id(), customer.toRow());
    }
}
