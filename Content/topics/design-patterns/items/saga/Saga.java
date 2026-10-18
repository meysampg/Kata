import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Deque;
import java.util.List;

// [[step
record Step(String name, Runnable action, Runnable compensation) {}
// ]]

// [[orchestrator
final class Saga {
    private final List<Step> steps;
    final List<String> log = new ArrayList<>();

    Saga(List<Step> steps) { this.steps = steps; }

    boolean run() {
        Deque<Step> done = new ArrayDeque<>();
        for (Step step : steps) {
            try {
                step.action().run();
                log.add("do " + step.name());
                done.push(step);
            } catch (RuntimeException e) {
                log.add("fail " + step.name());
                while (!done.isEmpty()) {
                    Step undo = done.pop();
                    undo.compensation().run();
                    log.add("undo " + undo.name());
                }
                return false;
            }
        }
        return true;
    }
}
// ]]

class Main {
    static int stock = 5;
    static int held = 0;

    static Saga checkout(boolean cardOk) {
        // [[definition
        return new Saga(List.of(
            new Step("reserve", () -> stock--, () -> stock++),
            new Step("hold-points", () -> held += 10, () -> held -= 10),
            new Step("charge", () -> {
                if (!cardOk) throw new IllegalStateException("declined");
            }, () -> {}),
            new Step("ship", () -> {}, () -> {})));
        // ]]
    }

    public static void main(String[] args) {
        for (boolean cardOk : new boolean[] {true, false}) {
            stock = 5;
            held = 0;
            var saga = checkout(cardOk);
            // [[run
            boolean ok = saga.run();
            System.out.println(ok + " " + saga.log
                + " stock=" + stock + " held=" + held);
            // ]]
        }
    }
}
