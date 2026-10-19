import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

final class Stats {
    private Stats() { }

    static int total(Collection<Integer> xs) {
        int sum = 0;
        for (int x : xs) {
            sum += x;
        }
        return sum;
    }

    static Map<String, Integer> lengths(Collection<String> words) {
        Map<String, Integer> out = new HashMap<>();
        for (String w : words) {
            out.put(w, w.length());
        }
        return out;
    }
}

final class Tally {
    private final List<Integer> history = new ArrayList<>();

    void record(int x) { history.add(x); }

    List<Integer> history() { return history; }
}
