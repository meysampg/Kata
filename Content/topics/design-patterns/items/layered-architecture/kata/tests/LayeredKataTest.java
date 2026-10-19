import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.lang.reflect.Proxy;
import java.util.ArrayList;
import java.util.List;
import kata.*;

class LayeredKataTest {
    static LoanController desk() {
        return Library.open(List.of(
            new Book("111", "Refactoring", false),
            new Book("222", "Domain-Driven Design", true)));
    }

    @Check(id = "lend-and-return")
    void lendAndReturn() {
        var desk = desk();
        Expect.equal("200 Refactoring", desk.lend("111"), "lending a free book");
        Expect.equal("409 already on loan", desk.lend("111"), "lending it again");
        Expect.equal("200 Refactoring", desk.giveBack("111"), "returning it");
        Expect.equal("200 Refactoring", desk.lend("111"), "lending after return");
    }

    @Check(id = "unknown-book")
    void unknownBook() {
        Expect.equal("404 unknown book", desk().lend("999"), "lend");
        Expect.equal("404 unknown book", desk().giveBack("999"), "giveBack");
    }

    @Check(id = "return-not-lent")
    void returnNotLent() {
        Expect.equal("409 not on loan", desk().giveBack("111"), "returning a free book");
        Expect.equal("200 Domain-Driven Design", desk().giveBack("222"), "returning a lent book");
    }

    @Check(id = "layers-exist", kind = Kind.DESIGN)
    void layersExist() {
        Class<?> repo = Types.named("BookRepository");
        Expect.isTrue(repo.isInterface(), "BookRepository should be an interface");
        Types.method(repo, "find", String.class);
        Types.method(repo, "save", Book.class);
        Types.constructor(Types.named("LoanService"), repo);
        Types.constructor(Types.named("LoanController"), Types.named("LoanService"));
    }

    @Check(id = "controller-skips-data", kind = Kind.DESIGN)
    void controllerSkipsData() {
        var controller = Source.type("LoanController");
        Expect.none(controller.mentions("BookRepository"),
            "LoanController reaches into the data layer");
        Expect.none(controller.mentions("InMemoryBookRepository"),
            "LoanController reaches into the data layer");
        Expect.none(controller.mentions("Map"), "LoanController still holds storage");
        Expect.none(controller.mentions("HashMap"), "LoanController still holds storage");
        Expect.none(controller.news("Book"), "LoanController builds domain objects itself");
    }

    @Check(id = "controller-uses-service", kind = Kind.DESIGN)
    void controllerUsesService() {
        Class<?> service = Types.named("LoanService");
        var f = Types.onlyFieldOfType(Types.named("LoanController"), service);
        Expect.isTrue(Modifier.isPrivate(f.getModifiers()) && Modifier.isFinal(f.getModifiers()),
            "LoanController." + f.getName() + " should be private final");
    }

    @Check(id = "service-skips-presentation", kind = Kind.DESIGN)
    void serviceSkipsPresentation() {
        var service = Source.type("LoanService");
        Expect.none(service.mentions("LoanController"),
            "LoanService refers to the presentation layer above it");
        Class<?> repo = Types.named("BookRepository");
        Types.onlyFieldOfType(Types.named("LoanService"), repo);
        Method lend = Types.method(Types.named("LoanService"), "lend", String.class);
        Expect.isTrue(lend.getReturnType() == Book.class,
            "LoanService.lend should return a Book, not a status line");
        Expect.none(service.news("InMemoryBookRepository"),
            "LoanService picks its own storage instead of using the interface");
    }

    @Check(id = "service-runs-on-any-repository", kind = Kind.DESIGN)
    void serviceRunsOnAnyRepository() throws Throwable {
        Class<?> repo = Types.named("BookRepository");
        List<Book> saved = new ArrayList<>();
        Object stub = Proxy.newProxyInstance(repo.getClassLoader(), new Class<?>[] {repo},
            (p, m, a) -> switch (m.getName()) {
                case "find" -> new Book("1", "Kata", false);
                case "save" -> { saved.add((Book) a[0]); yield null; }
                default -> null;
            });
        Object service = Types.create(Types.constructor(Types.named("LoanService"), repo), stub);
        Object lent = Types.call(Types.method(service.getClass(), "lend", String.class), service, "1");
        Expect.equal(new Book("1", "Kata", true), lent, "the book LoanService returns");
        Expect.equal(List.of(new Book("1", "Kata", true)), saved, "what reached the repository");
    }
}
