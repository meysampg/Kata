import java.util.ArrayList;
import java.util.HashMap;

// Every signature names a concrete collection class, so callers must too.
final class Stats {
    private Stats() { }

    static int total(ArrayList<Integer> xs) {
        int sum = 0;
        for (int x : xs) {
            sum += x;
        }
        return sum;
    }

    static HashMap<String, Integer> lengths(ArrayList<String> words) {
        HashMap<String, Integer> out = new HashMap<>();
        for (String w : words) {
            out.put(w, w.length());
        }
        return out;
    }
}

final class Tally {
    private final ArrayList<Integer> history = new ArrayList<>();

    void record(int x) { history.add(x); }

    ArrayList<Integer> history() { return history; }
}
