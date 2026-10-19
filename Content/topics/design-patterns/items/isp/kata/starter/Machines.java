import java.util.ArrayList;
import java.util.List;

// One fat interface: every machine must offer all three jobs.
interface Machine {
    void print(String doc);
    String scan();
    void fax(String doc, String number);
}

final class BasicPrinter implements Machine {
    final List<String> out = new ArrayList<>();

    public void print(String doc) { out.add(doc); }
    public String scan() { throw new UnsupportedOperationException(); }
    public void fax(String doc, String number) {
        throw new UnsupportedOperationException();
    }
}

final class MultiFunction implements Machine {
    final List<String> out = new ArrayList<>();

    public void print(String doc) { out.add(doc); }
    public String scan() { return "scan:" + out.size(); }
    public void fax(String doc, String number) {
        out.add("fax " + number + ": " + doc);
    }
}

final class Office {
    private Office() { }

    static int printAll(Machine m, List<String> docs) {
        for (String d : docs) {
            m.print(d);
        }
        return docs.size();
    }

    static String digitise(Machine m) { return m.scan().toUpperCase(); }

    static void send(Machine m, String doc, String number) {
        m.fax(doc, number);
    }
}
