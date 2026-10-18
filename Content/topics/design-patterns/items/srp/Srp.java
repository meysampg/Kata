import java.util.ArrayList;
import java.util.List;

record Line(String sku, int qty, long cents) {
    long amount() { return qty * cents; }
    String text() { return sku + " x" + qty; }
}

// [[before
final class InvoiceBefore {                    // three reasons to change
    private final List<Line> lines = new ArrayList<>();

    void add(Line line) { lines.add(line); }
    long total() {                             // pricing rules
        return lines.stream().mapToLong(Line::amount).sum();
    }
    String render() {                          // presentation
        var sb = new StringBuilder();
        for (Line l : lines) sb.append(l.text()).append(' ');
        return sb.append("= ").append(total() / 100).toString();
    }
    void save() { System.out.println("DB <- " + total()); }   // persistence
}
// ]]

// [[model
record Invoice(List<Line> lines) {
    Invoice { lines = List.copyOf(lines); }
    long total() { return lines.stream().mapToLong(Line::amount).sum(); }
}
// ]]

// [[format
final class InvoiceRenderer {
    String render(Invoice inv) {
        var sb = new StringBuilder();
        for (Line l : inv.lines()) sb.append(l.text()).append(' ');
        return sb.append("= ").append(inv.total() / 100).toString();
    }
}
// ]]

// [[store
@FunctionalInterface
interface InvoiceStore { void save(Invoice inv); }
// ]]

// [[service
final class BillingService {
    private final InvoiceRenderer renderer;
    private final InvoiceStore store;

    BillingService(InvoiceRenderer r, InvoiceStore s) {
        renderer = r;
        store = s;
    }

    String issue(Invoice inv) {
        store.save(inv);
        return renderer.render(inv);
    }
}
// ]]

class Main {
    public static void main(String[] args) {
        var lines = List.of(new Line("A1", 2, 1250), new Line("B7", 1, 500));
        var before = new InvoiceBefore();
        lines.forEach(before::add);
        before.save();
        System.out.println(before.render());

        var rows = new ArrayList<Invoice>();
        var service = new BillingService(new InvoiceRenderer(), rows::add);
        System.out.println(service.issue(new Invoice(lines)));
        System.out.println(rows.size() + " stored");
    }
}
