import java.util.ArrayList;
import java.util.List;

record Line(String sku, int qty, long cents) { }

// Finance changes the CSV, design changes the text, ops changes delivery.
// All three edit this one class.
final class ReportService {
    private final List<String> outbox;

    ReportService(List<String> outbox) { this.outbox = outbox; }

    String run(String csv) {
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
        StringBuilder sb = new StringBuilder();
        long total = 0;
        for (Line l : lines) {
            sb.append(l.sku()).append(" x").append(l.qty()).append('\n');
            total += l.qty() * l.cents();
        }
        sb.append(String.format("TOTAL %d.%02d", total / 100, total % 100));
        String text = sb.toString();
        outbox.add(text);
        return text;
    }
}

// Callers use this entry point. Keep its signature and behaviour.
final class Reports {
    private Reports() { }

    static String run(String csv, List<String> outbox) {
        return new ReportService(outbox).run(csv);
    }
}
