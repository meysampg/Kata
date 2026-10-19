import java.lang.reflect.Method;
import java.util.List;
import kata.*;

class IspKataTest {
    @Check(id = "printer-prints")
    void printerPrints() {
        BasicPrinter p = new BasicPrinter();
        int n = Office.printAll(new MultiFunction(), List.of("x"));
        p.print("a");
        p.print("b");
        Expect.equal(1, n, "documents printed");
        Expect.equal(List.of("a", "b"), p.out, "what BasicPrinter printed");
    }

    @Check(id = "multifunction-roles")
    void multifunctionRoles() {
        MultiFunction m = new MultiFunction();
        Office.printAll(m, List.of("a", "b"));
        Expect.equal("SCAN:2", Office.digitise(m), "digitise after two prints");
        Office.send(m, "memo", "555");
        Expect.equal(List.of("a", "b", "fax 555: memo"), m.out, "the machine's log");
    }

    @Check(id = "role-interfaces", kind = Kind.DESIGN)
    void roleInterfaces() {
        for (String role : List.of("Printer", "DocScanner", "Fax")) {
            Class<?> type = Types.named(role);
            Expect.isTrue(type.isInterface(), role + " should be an interface");
            Types.singleAbstractMethod(type);
        }
        Expect.equal("print", Types.singleAbstractMethod(Types.named("Printer")).getName(), "Printer's method");
        Expect.equal("scan", Types.singleAbstractMethod(Types.named("DocScanner")).getName(), "DocScanner's method");
        Expect.equal("fax", Types.singleAbstractMethod(Types.named("Fax")).getName(), "Fax's method");
    }

    @Check(id = "basic-printer-only-prints", kind = Kind.DESIGN)
    void basicPrinterOnlyPrints() {
        Class<?> basic = Types.named("BasicPrinter");
        Expect.isTrue(Types.named("Printer").isAssignableFrom(basic), "BasicPrinter should be a Printer");
        Expect.isTrue(!Types.named("DocScanner").isAssignableFrom(basic),
            "BasicPrinter cannot scan, so it should not be a DocScanner");
        Expect.isTrue(!Types.named("Fax").isAssignableFrom(basic),
            "BasicPrinter cannot fax, so it should not be a Fax");
        Expect.none(Source.type("BasicPrinter").mentions("UnsupportedOperationException"),
            "BasicPrinter still has methods it cannot honour");
    }

    @Check(id = "multifunction-plays-all-roles", kind = Kind.DESIGN)
    void multifunctionPlaysAllRoles() {
        Class<?> m = Types.named("MultiFunction");
        for (String role : List.of("Printer", "DocScanner", "Fax")) {
            Expect.isTrue(Types.named(role).isAssignableFrom(m), "MultiFunction should be a " + role);
        }
    }

    @Check(id = "office-asks-for-roles", kind = Kind.DESIGN)
    void officeAsksForRoles() {
        Class<?> office = Types.named("Office");
        Method print = Types.staticMethod(office, "printAll", Types.named("Printer"), List.class);
        Method scan = Types.staticMethod(office, "digitise", Types.named("DocScanner"));
        Method fax = Types.staticMethod(office, "send", Types.named("Fax"), String.class, String.class);
        Expect.equal(int.class, print.getReturnType(), "printAll's return type");
        Expect.equal(String.class, scan.getReturnType(), "digitise's return type");
        Expect.equal(void.class, fax.getReturnType(), "send's return type");
    }
}
