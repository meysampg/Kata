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

abstract class Report {
    protected abstract Sink createSink();

    final String render(Map<String, Integer> totals) {
        Sink sink = createSink();
        totals.forEach(sink::write);
        return sink.close();
    }
}

final class CsvReport extends Report {
    protected Sink createSink() { return new CsvSink(); }
}

final class JsonReport extends Report {
    protected Sink createSink() { return new JsonSink(); }
}

final class Reports {
    private Reports() { }

    static Report forFormat(String format) {
        return switch (format) {
            case "csv" -> new CsvReport();
            case "json" -> new JsonReport();
            default -> throw new IllegalArgumentException(
                "unknown format: " + format);
        };
    }

    static String render(String format, Map<String, Integer> totals) {
        return forFormat(format).render(totals);
    }
}
