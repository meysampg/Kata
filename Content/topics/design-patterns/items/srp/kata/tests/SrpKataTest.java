import java.lang.reflect.Constructor;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.List;
import kata.*;

class SrpKataTest {
    static final String CSV = "pen,2,150\n\n book , 1 ,1299\n";

    @Check(id = "report-text")
    void reportText() {
        List<String> outbox = new ArrayList<>();
        String text = Reports.run(CSV, outbox);
        Expect.equal("pen x2\nbook x1\nTOTAL 15.99", text, "the report text");
    }

    @Check(id = "report-is-sent")
    void reportIsSent() {
        List<String> outbox = new ArrayList<>();
        String text = Reports.run("a,1,5", outbox);
        Expect.equal(List.of(text), outbox, "the messages sent");
    }

    @Check(id = "bad-rows-rejected")
    void badRowsRejected() {
        List<String> outbox = new ArrayList<>();
        Expect.raises(IllegalArgumentException.class,
            () -> Reports.run("a,1", outbox), "a row with two fields");
        Expect.raises(NumberFormatException.class,
            () -> Reports.run("a,x,5", outbox), "a quantity that is not a number");
        Expect.isTrue(outbox.isEmpty(), "nothing should be sent for a bad file");
    }

    @Check(id = "parser-role", kind = Kind.DESIGN)
    void parserRole() throws Throwable {
        Class<?> parser = Types.named("InvoiceParser");
        Object p = Types.create(Types.constructor(parser));
        Method parse = Types.method(parser, "parse", String.class);
        Object lines = Types.call(parse, p, CSV);
        Expect.isTrue(lines instanceof List<?> l && l.size() == 2,
            "InvoiceParser.parse should return the two lines of the CSV");
        var src = Source.type("InvoiceParser");
        Expect.none(src.calls("append"), "InvoiceParser also builds text");
        Expect.none(src.news("StringBuilder"), "InvoiceParser also builds text");
    }

    @Check(id = "formatter-role", kind = Kind.DESIGN)
    void formatterRole() throws Throwable {
        Class<?> parser = Types.named("InvoiceParser");
        Class<?> formatter = Types.named("InvoiceFormatter");
        Object lines = Types.call(Types.method(parser, "parse", String.class),
            Types.create(Types.constructor(parser)), CSV);
        Object f = Types.create(Types.constructor(formatter));
        Object text = Types.call(Types.method(formatter, "format", List.class), f, lines);
        Expect.equal("pen x2\nbook x1\nTOTAL 15.99", text, "InvoiceFormatter.format");
        var src = Source.type("InvoiceFormatter");
        Expect.none(src.calls("split"), "InvoiceFormatter also parses");
        Expect.none(src.calls("parseLong"), "InvoiceFormatter also parses");
    }

    @Check(id = "sender-role", kind = Kind.DESIGN)
    void senderRole() {
        Class<?> sender = Types.named("Sender");
        Expect.isTrue(sender.isInterface(), "Sender should be an interface");
        var m = Types.singleAbstractMethod(sender);
        Expect.equal("send", m.getName(), "the method name");
        Expect.equal(List.of(String.class), List.of(m.getParameterTypes()), "send's parameters");
    }

    @Check(id = "service-only-coordinates", kind = Kind.DESIGN)
    void serviceOnlyCoordinates() {
        var service = Source.type("ReportService");
        Expect.none(service.calls("split"), "ReportService still parses the CSV");
        Expect.none(service.calls("parseInt"), "ReportService still parses the CSV");
        Expect.none(service.calls("parseLong"), "ReportService still parses the CSV");
        Expect.none(service.news("StringBuilder"), "ReportService still builds the text");
        Expect.none(service.calls("append"), "ReportService still builds the text");
        Expect.none(service.calls("add"), "ReportService still delivers into a list itself");
    }

    @Check(id = "parts-are-swappable", kind = Kind.DESIGN)
    void partsAreSwappable() throws Throwable {
        Class<?> parser = Types.named("InvoiceParser");
        Class<?> formatter = Types.named("InvoiceFormatter");
        Class<?> sender = Types.named("Sender");
        List<Object> got = new ArrayList<>();
        Object spy = Types.implement(sender, args -> { got.add(args[0]); return null; });
        Constructor<?> c = Types.constructor(Types.named("ReportService"), parser, formatter, sender);
        Object service = Types.create(c, Types.create(Types.constructor(parser)),
            Types.create(Types.constructor(formatter)), spy);
        Object text = Types.call(Types.method(service.getClass(), "run", String.class), service, "z,3,100");
        Expect.equal("z x3\nTOTAL 3.00", text, "the returned report");
        Expect.equal(List.of("z x3\nTOTAL 3.00"), got, "what the injected Sender received");
    }
}
