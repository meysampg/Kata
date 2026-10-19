import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;

record Request(String path, Map<String, String> headers) { }

record Response(int status, String body) { }

interface Handler {
    Response handle(Request request);
}

// Where the platform collects what services report.
final class Telemetry {
    final List<String> accessLog = new ArrayList<>();
    final Map<Integer, Integer> metrics = new TreeMap<>();

    void record(String path, int status) {
        accessLog.add(path + " " + status);
        metrics.merge(status, 1, Integer::sum);
    }
}
