import java.util.ArrayList;
import java.util.List;

// [[before
interface Machine {
    void print(String doc);
    String scan();
    void fax(String doc, String number);
}

final class BasicPrinterBefore implements Machine {
    public void print(String doc) { System.out.println("print " + doc); }
    public String scan() { throw new UnsupportedOperationException(); }
    public void fax(String d, String n) {
        throw new UnsupportedOperationException();
    }
}
// ]]

// [[roles
interface Printer { void print(String doc); }
interface DocScanner { String scan(); }
interface Fax { void fax(String doc, String number); }
// ]]

// [[impls
final class BasicPrinter implements Printer {
    final List<String> out = new ArrayList<>();
    public void print(String doc) { out.add(doc); }
}

final class OfficeMachine implements Printer, DocScanner, Fax {
    public void print(String doc) { System.out.println("print " + doc); }
    public String scan() { return "scan#1"; }
    public void fax(String doc, String number) {
        System.out.println("fax " + doc + " to " + number);
    }
}
// ]]

// [[clients
final class ReportJob {
    private final Printer printer;            // needs one capability only

    ReportJob(Printer printer) { this.printer = printer; }
    void run() { printer.print("Q3 report"); }
}
// ]]

class Main {
    public static void main(String[] args) {
        try {
            new BasicPrinterBefore().scan();
        } catch (UnsupportedOperationException e) {
            System.out.println("before: scan() unsupported");
        }
        var basic = new BasicPrinter();
        new ReportJob(basic).run();
        System.out.println("basic: " + basic.out);
        new ReportJob(new OfficeMachine()).run();
        new ReportJob(doc -> System.out.println("lambda " + doc)).run();
        new OfficeMachine().fax("memo", "555-0100");
    }
}
