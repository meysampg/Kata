import java.util.ArrayList;
import java.util.List;
import java.util.Map;

interface Sink {
    void write(String name, int value);
    String close();
}

final class CsvSink implements Sink {
    private final List<String> rows = new ArrayList<>();
    public void write(String name, int value) { rows.add(name + "," + value); }
    public String close() { return String.join("\n", rows); }
}

final class JsonSink implements Sink {
    private final List<String> fields = new ArrayList<>();
    public void write(String name, int value) {
        fields.add("\"" + name + "\":" + value);
    }
    public String close() { return "{" + String.join(",", fields) + "}"; }
}

// Every new export format is another branch in this class.
final class Report {
    private final String format;

    Report(String format) { this.format = format; }

    String render(Map<String, Integer> totals) {
        Sink sink;
        if (format.equals("csv")) {
            sink = new CsvSink();
        } else if (format.equals("json")) {
            sink = new JsonSink();
        } else {
            throw new IllegalArgumentException("unknown format: " + format);
        }
        totals.forEach(sink::write);
        return sink.close();
    }
}

// Callers use this entry point. Keep its signature and behaviour.
final class Reports {
    private Reports() { }

    static String render(String format, Map<String, Integer> totals) {
        return new Report(format).render(totals);
    }
}
