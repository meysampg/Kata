import java.util.ArrayList;
import java.util.List;

interface Printer { void print(String doc); }
interface DocScanner { String scan(); }
interface Fax { void fax(String doc, String number); }

final class BasicPrinter implements Printer {
    final List<String> out = new ArrayList<>();

    public void print(String doc) { out.add(doc); }
}

final class MultiFunction implements Printer, DocScanner, Fax {
    final List<String> out = new ArrayList<>();

    public void print(String doc) { out.add(doc); }
    public String scan() { return "scan:" + out.size(); }
    public void fax(String doc, String number) {
        out.add("fax " + number + ": " + doc);
    }
}

final class Office {
    private Office() { }

    static int printAll(Printer p, List<String> docs) {
        for (String d : docs) {
            p.print(d);
        }
        return docs.size();
    }

    static String digitise(DocScanner s) { return s.scan().toUpperCase(); }

    static void send(Fax f, String doc, String number) {
        f.fax(doc, number);
    }
}
