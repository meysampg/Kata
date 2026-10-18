import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;
import java.util.function.Supplier;

// [[product
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
// ]]

// [[creator
abstract class Report {
    protected abstract Sink createSink();

    final String render(Map<String, Integer> totals) {
        Sink sink = createSink();
        totals.forEach(sink::write);
        return sink.close();
    }

    static Report using(Supplier<Sink> factory) {
        return new Report() {
            protected Sink createSink() { return factory.get(); }
        };
    }
}
// ]]

// [[subclasses
final class CsvReport extends Report {
    protected Sink createSink() { return new CsvSink(); }
}

final class JsonReport extends Report {
    protected Sink createSink() { return new JsonSink(); }
}
// ]]

class Main {
    public static void main(String[] args) {
        var totals = new TreeMap<>(Map.of("eu", 5, "us", 7));
        // [[client
        for (Report report : List.of(new CsvReport(), new JsonReport())) {
            System.out.println(report.render(totals));
        }
        // ]]
        // [[injected
        Report inline = Report.using(JsonSink::new);
        System.out.println(inline.render(totals));
        // ]]
    }
}
