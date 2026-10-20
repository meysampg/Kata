import java.lang.reflect.Constructor;
import java.lang.reflect.Method;
import java.util.HashMap;
import java.util.Map;
import kata.*;

class DataMapperKataTest {
    static Map<Long, Row> table() {
        var t = new HashMap<Long, Row>();
        t.put(1L, new Row(1, "Ada", "ada@old.org"));
        t.put(2L, new Row(2, "Bob", "broken"));
        return t;
    }

    @Check(id = "find-maps-columns")
    void findMapsColumns() {
        Customer c = new CustomerMapper(table()).find(1).orElseThrow();
        Expect.equal(1L, c.id(), "id");
        Expect.equal("Ada", c.name(), "name");
        Expect.equal(new Email("ada@old.org"), c.email(), "email");
    }

    @Check(id = "find-missing-is-empty")
    void findMissingIsEmpty() {
        Expect.isTrue(new CustomerMapper(table()).find(99).isEmpty(), "find of an unknown id");
    }

    @Check(id = "save-writes-row")
    void saveWritesRow() {
        var t = table();
        var mapper = new CustomerMapper(t);
        mapper.save(new Customer(3, "Cy", new Email("cy@x.org")));
        Expect.equal(new Row(3, "Cy", "cy@x.org"), t.get(3L), "the inserted row");
    }

    @Check(id = "save-updates-and-lowercases")
    void saveUpdatesAndLowercases() {
        var t = table();
        var mapper = new CustomerMapper(t);
        Customer ada = mapper.find(1).orElseThrow();
        ada.changeEmail(new Email("Ada@New.ORG"));
        mapper.save(ada);
        Expect.equal(new Row(1, "Ada", "ada@new.org"), t.get(1L), "the stored row");
        Expect.equal(2, t.size(), "rows in the table");
    }

    @Check(id = "corrupt-row-rejected")
    void corruptRowRejected() {
        Expect.raises(IllegalArgumentException.class,
            () -> new CustomerMapper(table()).find(2), "find of a row with a bad email");
    }

    @Check(id = "customer-has-no-row-in-its-api", kind = Kind.DESIGN)
    void customerHasNoRowInItsApi() {
        Class<?> customer = Types.named("Customer");
        Class<?> row = Types.named("Row");
        for (Method m : customer.getDeclaredMethods()) {
            Expect.isTrue(m.getReturnType() != row && !java.util.List.of(m.getParameterTypes()).contains(row),
                "Customer." + m.getName() + " still deals in Row");
        }
        for (Constructor<?> c : customer.getDeclaredConstructors()) {
            Expect.isTrue(!java.util.List.of(c.getParameterTypes()).contains(row),
                "A Customer constructor still takes a Row");
        }
        Expect.isTrue(Types.fieldsOfType(customer, row).isEmpty(), "Customer holds a Row");
    }

    @Check(id = "customer-source-free-of-table", kind = Kind.DESIGN)
    void customerSourceFreeOfTable() {
        var customer = Source.type("Customer");
        Expect.none(customer.mentions("Row"), "Customer still mentions Row");
        Expect.none(customer.mentions("emailAddr"), "Customer still knows the emailAddr column");
    }

    @Check(id = "mapper-owns-conversion", kind = Kind.DESIGN)
    void mapperOwnsConversion() {
        var mapper = Source.type("CustomerMapper");
        Expect.isTrue(!mapper.news("Row").isEmpty(),
            "CustomerMapper should build the Row itself");
        Expect.isTrue(!mapper.news("Customer").isEmpty(),
            "CustomerMapper should build the Customer itself");
        Expect.isTrue(!mapper.calls("emailAddr").isEmpty() && !mapper.calls("email").isEmpty(),
            "CustomerMapper should read both sides itself: row.emailAddr() and customer.email()");
        Expect.isTrue(!mapper.calls("toLowerCase").isEmpty(),
            "The lower-casing is part of the row format; it belongs in CustomerMapper");
        Expect.none(Source.type("Customer").calls("toLowerCase"),
            "Customer still formats the stored email");
        for (Method m : Types.named("Customer").getDeclaredMethods()) {
            Expect.isTrue(!java.lang.reflect.Modifier.isStatic(m.getModifiers())
                    || m.getReturnType() != Types.named("Customer"),
                "Customer." + m.getName() + " still builds a Customer from stored data;"
                + " let CustomerMapper call the constructor");
        }
    }
}
