import java.lang.reflect.Field;
import java.lang.reflect.Modifier;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Deque;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicReference;
import kata.*;

class ReactorKataTest {
    static Ready ev(String channel, Op op, String data) {
        return new Ready(channel, op, data);
    }

    /** Hands out scripted batches, then empty lists, and counts calls. */
    static class Script implements Demultiplexer {
        final Deque<List<Ready>> batches = new ArrayDeque<>();
        int selects;

        @SafeVarargs
        Script(List<Ready>... all) {
            for (List<Ready> b : all) {
                batches.add(b);
            }
        }

        @Override
        public List<Ready> select() {
            selects++;
            return batches.isEmpty() ? List.of() : batches.poll();
        }
    }

    static void runWithin(Reactor reactor) {
        Expect.completesWithin(2000, () -> {
            reactor.run();
            return null;
        }, "Reactor.run()");
    }

    @Check(id = "dispatches-by-operation", timeoutMs = 4000)
    void dispatchesByOperation() {
        List<String> log = new ArrayList<>();
        Script script = new Script(List.of(
            ev("c1", Op.ACCEPT, ""), ev("c1", Op.READ, "hi"),
            ev("c1", Op.CLOSE, "")));
        Reactor reactor = new Reactor(script)
            .on(Op.ACCEPT, e -> log.add("accept " + e.channel()))
            .on(Op.READ, e -> log.add("read " + e.data()))
            .on(Op.CLOSE, e -> log.add("close " + e.channel()));
        runWithin(reactor);
        Expect.equal(List.of("accept c1", "read hi", "close c1"), log,
            "handler calls");
    }

    @Check(id = "keeps-order-across-batches", timeoutMs = 4000)
    void keepsOrderAcrossBatches() {
        List<String> log = new ArrayList<>();
        Script script = new Script(
            List.of(ev("a", Op.READ, "1"), ev("b", Op.READ, "2")),
            List.of(ev("a", Op.READ, "3")),
            List.of(ev("b", Op.READ, "4"), ev("a", Op.READ, "5")));
        runWithin(new Reactor(script).on(Op.READ, e -> log.add(e.data())));
        Expect.equal(List.of("1", "2", "3", "4", "5"), log, "events handled");
    }

    @Check(id = "run-ends-when-select-is-empty", timeoutMs = 4000)
    void runEndsWhenSelectIsEmpty() {
        Script script = new Script(List.of(ev("a", Op.READ, "x")),
            List.of(ev("a", Op.READ, "y")));
        runWithin(new Reactor(script).on(Op.READ, e -> { }));
        Expect.equal(3, script.selects, "calls to select()");
        Script none = new Script();
        runWithin(new Reactor(none));
        Expect.equal(1, none.selects, "calls to select() with no events");
    }

    @Check(id = "later-handler-replaces-earlier", timeoutMs = 4000)
    void laterHandlerReplacesEarlier() {
        List<String> log = new ArrayList<>();
        Script script = new Script(List.of(ev("a", Op.READ, "x")));
        runWithin(new Reactor(script)
            .on(Op.READ, e -> log.add("old"))
            .on(Op.READ, e -> log.add("new")));
        Expect.equal(List.of("new"), log, "handlers that ran");
    }

    @Check(id = "unregistered-operation-fails-loudly", timeoutMs = 4000)
    void unregisteredOperationFailsLoudly() {
        Script script = new Script(List.of(ev("a", Op.CLOSE, "")));
        Reactor reactor = new Reactor(script).on(Op.READ, e -> { });
        IllegalStateException e = Expect.raises(IllegalStateException.class,
            reactor::run, "run() with an event nobody handles");
        Expect.isTrue(e.getMessage() != null
                && e.getMessage().contains("CLOSE"),
            "The message should name the operation, but was: "
            + e.getMessage());
    }

    @Check(id = "handlers-run-on-the-calling-thread", timeoutMs = 4000)
    void handlersRunOnTheCallingThread() {
        AtomicReference<Thread> seen = new AtomicReference<>();
        Script script = new Script(List.of(ev("a", Op.READ, "x")));
        Reactor reactor = new Reactor(script)
            .on(Op.READ, e -> seen.set(Thread.currentThread()));
        reactor.run();
        Expect.isTrue(seen.get() == Thread.currentThread(),
            "A handler ran on " + (seen.get() == null ? "no thread"
            : seen.get().getName()) + "; a reactor dispatches on the thread "
            + "that called run()");
    }

    @Check(id = "stop-ends-the-loop-after-the-batch", timeoutMs = 4000)
    void stopEndsTheLoopAfterTheBatch() {
        List<String> log = new ArrayList<>();
        Script script = new Script(
            List.of(ev("a", Op.CLOSE, ""), ev("a", Op.READ, "same batch")),
            List.of(ev("a", Op.READ, "next batch")));
        AtomicReference<Reactor> self = new AtomicReference<>();
        Reactor reactor = new Reactor(script)
            .on(Op.CLOSE, e -> self.get().stop())
            .on(Op.READ, e -> log.add(e.data()));
        self.set(reactor);
        runWithin(reactor);
        Expect.equal(List.of("same batch"), log, "events handled");
        Expect.equal(1, script.selects, "calls to select()");
    }

    @Check(id = "handlers-can-register-handlers", timeoutMs = 4000)
    void handlersCanRegisterHandlers() {
        List<String> log = new ArrayList<>();
        Script script = new Script(
            List.of(ev("c", Op.ACCEPT, ""), ev("c", Op.READ, "first")),
            List.of(ev("c", Op.READ, "second")));
        AtomicReference<Reactor> self = new AtomicReference<>();
        Reactor reactor = new Reactor(script).on(Op.ACCEPT, e ->
            self.get().on(Op.READ, r -> log.add(r.channel() + ":" + r.data())));
        self.set(reactor);
        runWithin(reactor);
        Expect.equal(List.of("c:first", "c:second"), log, "reads handled");
    }

    @Check(id = "no-branching-on-the-operation", kind = Kind.DESIGN)
    void noBranchingOnTheOperation() {
        var reactor = Source.type("Reactor");
        Expect.none(reactor.switches(), "Reactor switches on the operation");
        Expect.none(reactor.instanceofs(), "Reactor inspects event types");
        for (Op op : Op.values()) {
            Expect.none(reactor.mentions(op.name()), "Reactor names "
                + op + "; it should only look handlers up by operation");
        }
    }

    @Check(id = "registry-is-a-private-final-map", kind = Kind.DESIGN)
    void registryIsAPrivateFinalMap() {
        Field found = null;
        for (Field f : Reactor.class.getDeclaredFields()) {
            if (Map.class.isAssignableFrom(f.getType())) {
                found = f;
            }
        }
        Expect.isTrue(found != null,
            "Reactor should keep its handlers in a Map field");
        int m = found.getModifiers();
        Expect.isTrue(Modifier.isPrivate(m) && Modifier.isFinal(m),
            "Reactor." + found.getName() + " should be private final");
    }
}
