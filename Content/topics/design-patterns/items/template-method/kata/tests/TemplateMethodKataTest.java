import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.util.List;
import kata.*;

class TemplateMethodKataTest {
    static final List<String> CSV = List.of(
        "ana, 31", "", "kid, 12", "bo,40");
    static final List<String> PIPE = List.of(
        "# staff", "ana | 31", "kid|12", "   ", "bo|40");
    static final List<User> ADULTS = List.of(new User("ana", 31), new User("bo", 40));

    @Check(id = "csv-import")
    void csvImport() {
        CsvImporter importer = new CsvImporter();
        Expect.equal(2, importer.run(CSV), "rows saved");
        Expect.equal(ADULTS, importer.saved(), "saved users");
        Expect.equal(List.of("open", "skip kid", "saved 2", "close"), importer.log(), "log");
    }

    @Check(id = "pipe-import")
    void pipeImport() {
        PipeImporter importer = new PipeImporter();
        Expect.equal(2, importer.run(PIPE), "rows saved");
        Expect.equal(ADULTS, importer.saved(), "saved users");
        Expect.equal(List.of("open", "skip kid", "saved 2", "close"), importer.log(), "log");
    }

    @Check(id = "comments-only-in-pipe")
    void commentsOnlyInPipe() {
        CsvImporter csv = new CsvImporter();
        Expect.raises(RuntimeException.class,
            () -> csv.run(List.of("# staff")), "a '#' line in CSV is a bad row");
        PipeImporter pipe = new PipeImporter();
        Expect.equal(0, pipe.run(List.of("# a|b", "#", "")), "only comments");
    }

    @Check(id = "closes-after-bad-row")
    void closesAfterBadRow() {
        PipeImporter importer = new PipeImporter();
        Expect.raises(NumberFormatException.class,
            () -> importer.run(List.of("ana|31", "bo|old", "cy|20")), "a bad age");
        Expect.equal(List.of("open", "close"), importer.log(), "log after the failure");
        Expect.equal(List.of(new User("ana", 31)), importer.saved(), "rows before the failure");
    }

    /** The superclass both importers share, or a failure that says so. */
    static Class<?> base() {
        Class<?> base = Types.named("CsvImporter").getSuperclass();
        Expect.isTrue(base != Object.class,
            "CsvImporter needs a common abstract superclass that owns the skeleton");
        return base;
    }

    @Check(id = "shared-abstract-base", kind = Kind.DESIGN)
    void sharedAbstractBase() {
        Class<?> pipe = Types.named("PipeImporter");
        Class<?> base = base();
        Expect.isTrue(pipe.getSuperclass() == base, "PipeImporter should extend the same superclass as CsvImporter");
        Expect.isTrue(Modifier.isAbstract(base.getModifiers()), base.getSimpleName() + " should be abstract");
    }

    @Check(id = "run-is-final", kind = Kind.DESIGN)
    void runIsFinal() {
        Class<?> base = base();
        Method run = Types.method(base, "run", List.class);
        int m = run.getModifiers();
        Expect.equal(base, run.getDeclaringClass(), "the class declaring run");
        Expect.isTrue(Modifier.isFinal(m), base.getSimpleName() + ".run is the template and should be final");
        Expect.isTrue(!Modifier.isPrivate(m), base.getSimpleName() + ".run should be callable by clients");
    }

    @Check(id = "steps-are-not-public", kind = Kind.DESIGN)
    void stepsAreNotPublic() {
        Class<?> base = base();
        int abstracts = 0;
        for (Method m : base.getDeclaredMethods()) {
            if (Modifier.isAbstract(m.getModifiers())) {
                abstracts++;
                Expect.isTrue(!Modifier.isPublic(m.getModifiers()),
                    "Step " + m.getName() + " is abstract and should not be public; only the template is");
            }
        }
        Expect.isTrue(abstracts > 0, base.getSimpleName() + " needs an abstract step for the format");
    }

    @Check(id = "subclasses-only-parse", kind = Kind.DESIGN)
    void subclassesOnlyParse() {
        for (String name : List.of("CsvImporter", "PipeImporter")) {
            var shape = Source.type(name);
            Expect.none(shape.mentions("log"), name + " still writes the log itself");
            Expect.none(shape.mentions("saved"), name + " still stores users itself");
            Expect.none(shape.calls("isBlank"), name + " still skips blank lines itself");
        }
    }
}
