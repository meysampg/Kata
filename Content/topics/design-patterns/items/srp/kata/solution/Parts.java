import java.util.ArrayList;
import java.util.List;

record Line(String sku, int qty, long cents) { }

@FunctionalInterface
interface Sender {
    void send(String text);
}

final class InvoiceParser {
    List<Line> parse(String csv) {
        List<Line> lines = new ArrayList<>();
        for (String row : csv.split("\n")) {
            if (row.isBlank()) {
                continue;
            }
            String[] p = row.split(",");
            if (p.length != 3) {
                throw new IllegalArgumentException("bad row: " + row);
            }
            lines.add(new Line(p[0].trim(),
                Integer.parseInt(p[1].trim()), Long.parseLong(p[2].trim())));
        }
        return lines;
    }
}

final class InvoiceFormatter {
    String format(List<Line> lines) {
        StringBuilder sb = new StringBuilder();
        long total = 0;
        for (Line l : lines) {
            sb.append(l.sku()).append(" x").append(l.qty()).append('\n');
            total += l.qty() * l.cents();
        }
        sb.append(String.format("TOTAL %d.%02d", total / 100, total % 100));
        return sb.toString();
    }
}
