import java.lang.reflect.Constructor;
import java.util.ArrayList;
import java.util.List;
import kata.*;

class SagaKataTest {
    static final List<String> trace = new ArrayList<>();

    static Step ok(String name) {
        return new Step(name, () -> { }, () -> trace.add("comp " + name));
    }

    static Step failing(String name) {
        return new Step(name, () -> { throw new IllegalStateException(name); },
            () -> trace.add("comp " + name));
    }

    static Step brokenUndo(String name) {
        return new Step(name, () -> { },
            () -> { throw new IllegalStateException("undo " + name); });
    }

    @Check(id = "happy-path")
    void happyPath() {
        trace.clear();
        Saga saga = new Saga(List.of(ok("reserve"), ok("charge"), ok("ship")));
        Expect.isTrue(saga.run(), "a saga whose steps all succeed returns true");
        Expect.equal(List.of("do reserve", "do charge", "do ship"), saga.log(), "the log");
        Expect.equal(List.of(), trace, "compensations that ran");
    }

    @Check(id = "undo-in-reverse")
    void undoInReverse() {
        trace.clear();
        Saga saga = new Saga(List.of(ok("reserve"), ok("hold"), failing("charge"), ok("ship")));
        Expect.isTrue(!saga.run(), "a failing step makes run() return false");
        Expect.equal(List.of("comp hold", "comp reserve"), trace,
            "compensations should run newest first");
        Expect.equal(List.of("do reserve", "do hold", "fail charge", "undo hold", "undo reserve"),
            saga.log(), "the log");
    }

    @Check(id = "failed-step-not-undone")
    void failedStepNotUndone() {
        trace.clear();
        new Saga(List.of(failing("charge"), ok("ship"))).run();
        Expect.equal(List.of(), trace, "compensations: nothing succeeded, so nothing to undo");
    }

    @Check(id = "stops-at-failure")
    void stopsAtFailure() {
        trace.clear();
        int[] shipped = {0};
        Step ship = new Step("ship", () -> shipped[0]++, () -> { });
        new Saga(List.of(failing("charge"), ship)).run();
        Expect.equal(0, shipped[0], "steps after the failure that ran");
    }

    @Check(id = "undo-continues-after-failure")
    void undoContinues() {
        trace.clear();
        Saga saga = new Saga(List.of(ok("a"), brokenUndo("b"), ok("c"), failing("d")));
        Expect.isTrue(!saga.run(), "run() still reports failure");
        Expect.equal(List.of("comp c", "comp a"), trace,
            "a compensation that throws must not stop the older ones");
        Expect.equal(List.of("do a", "do b", "do c", "fail d", "undo c", "stuck b", "undo a"),
            saga.log(), "the log");
    }

    @Check(id = "empty-saga")
    void emptySaga() {
        Saga saga = new Saga(List.of());
        Expect.isTrue(saga.run(), "an empty saga succeeds");
        Expect.equal(List.of(), saga.log(), "the log");
    }

    @Check(id = "saga-uses-compensation", kind = Kind.DESIGN)
    void usesCompensation() {
        var saga = Source.type("Saga");
        Expect.isTrue(!saga.calls("compensation").isEmpty(),
            "Saga never calls a step's compensation()");
        Expect.isTrue(!saga.calls("action").isEmpty(), "Saga never calls a step's action()");
    }

    @Check(id = "saga-knows-no-step-names", kind = Kind.DESIGN)
    void knowsNoNames() {
        Expect.none(Source.type("Saga").comparedStrings(),
            "Saga compares step names; the workflow should be data, not code");
        Expect.none(Source.type("Saga").switches(), "Saga switches on something");
    }

    @Check(id = "saga-takes-step-list", kind = Kind.DESIGN)
    void takesList() {
        Constructor<?> c = Types.constructor(Types.named("Saga"), List.class);
        Expect.isTrue(c != null, "Saga(List<Step>) is missing");
    }
}
