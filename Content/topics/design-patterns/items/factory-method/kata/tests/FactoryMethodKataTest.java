import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.util.Map;
import java.util.TreeMap;
import kata.*;

class FactoryMethodKataTest {
    static final Map<String, Integer> TOTALS =
        new TreeMap<>(Map.of("eu", 5, "us", 7));

    static Method hookOf(Class<?> report) {
        java.util.List<Method> abstracts = new java.util.ArrayList<>();
        for (Method m : report.getDeclaredMethods()) {
            if (Modifier.isAbstract(m.getModifiers())) abstracts.add(m);
        }
        Expect.equal(1, abstracts.size(), "abstract methods declared by Report");
        return abstracts.get(0);
    }

    @Check(id = "csv-output")
    void csvOutput() {
        Expect.equal("eu,5\nus,7", Reports.render("csv", TOTALS), "csv report");
    }

    @Check(id = "json-output")
    void jsonOutput() {
        Expect.equal("{\"eu\":5,\"us\":7}", Reports.render("json", TOTALS), "json report");
    }

    @Check(id = "empty-totals")
    void emptyTotals() {
        Expect.equal("", Reports.render("csv", Map.of()), "empty csv");
        Expect.equal("{}", Reports.render("json", Map.of()), "empty json");
    }

    @Check(id = "unknown-format")
    void unknownFormat() {
        Expect.raises(IllegalArgumentException.class,
            () -> Reports.render("xml", TOTALS), "an unknown format");
    }

    @Check(id = "report-has-factory-method", kind = Kind.DESIGN)
    void reportHasFactoryMethod() {
        Class<?> report = Types.named("Report");
        Class<?> sink = Types.named("Sink");
        Expect.isTrue(Modifier.isAbstract(report.getModifiers()),
            "Report should be abstract: subclasses decide which Sink to create");
        Method hook = hookOf(report);
        Expect.equal(sink, hook.getReturnType(),
            "the return type of Report." + hook.getName());
    }

    @Check(id = "render-uses-the-hook", kind = Kind.DESIGN)
    void renderUsesTheHook() {
        Method hook = hookOf(Types.named("Report"));
        var render = Source.type("Report").method("render");
        Expect.isTrue(!render.calls(hook.getName()).isEmpty(),
            "Report.render should obtain its Sink by calling " + hook.getName() + "()");
    }

    @Check(id = "report-does-not-choose-a-sink", kind = Kind.DESIGN)
    void reportDoesNotChooseASink() {
        var report = Source.type("Report");
        Expect.none(report.news("CsvSink"), "Report still creates a CsvSink itself");
        Expect.none(report.news("JsonSink"), "Report still creates a JsonSink itself");
        Expect.none(report.comparedStrings(), "Report still compares format names");
        Expect.none(report.switches(), "Report still switches on the format");
    }

    @Check(id = "report-keeps-no-format", kind = Kind.DESIGN)
    void reportKeepsNoFormat() {
        Class<?> report = Types.named("Report");
        Expect.isTrue(Types.fieldsOfType(report, String.class).isEmpty(),
            "Report should no longer store the format name");
    }

    @Check(id = "format-lookup-in-reports", kind = Kind.DESIGN)
    void formatLookupInReports() throws Throwable {
        Class<?> report = Types.named("Report");
        Method forFormat = Types.staticMethod(Types.named("Reports"), "forFormat", String.class);
        Expect.isTrue(report.isAssignableFrom(forFormat.getReturnType()),
            "Reports.forFormat should return a Report");
        Expect.isTrue(report.isInstance(Types.call(forFormat, null, "csv")),
            "csv should resolve to a Report");
        Expect.raises(IllegalArgumentException.class,
            () -> Types.call(forFormat, null, "xml"), "an unknown format in forFormat");
    }
}
