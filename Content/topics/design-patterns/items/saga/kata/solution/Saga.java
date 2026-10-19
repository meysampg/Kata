import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Deque;
import java.util.List;

final class Saga {
    private final List<Step> steps;
    private final List<String> log = new ArrayList<>();

    Saga(List<Step> steps) {
        this.steps = List.copyOf(steps);
    }

    boolean run() {
        Deque<Step> done = new ArrayDeque<>();
        for (Step step : steps) {
            try {
                step.action().run();
            } catch (RuntimeException e) {
                log.add("fail " + step.name());
                compensate(done);
                return false;
            }
            log.add("do " + step.name());
            done.push(step);
        }
        return true;
    }

    private void compensate(Deque<Step> done) {
        while (!done.isEmpty()) {
            Step step = done.pop();
            try {
                step.compensation().run();
                log.add("undo " + step.name());
            } catch (RuntimeException e) {
                log.add("stuck " + step.name());
            }
        }
    }

    List<String> log() {
        return List.copyOf(log);
    }
}
