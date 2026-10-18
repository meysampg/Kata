import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;

class Main {
    // [[before
    static int totalBefore(ArrayList<Integer> xs) {   // demands one class
        int sum = 0;
        for (int x : xs) sum += x;
        return sum;
    }
    // ]]

    // [[after
    static int total(Collection<Integer> xs) {        // demands a capability
        int sum = 0;
        for (int x : xs) sum += x;
        return sum;
    }
    // ]]

    // [[swap
    static Map<String, Integer> lengths(List<String> ws, boolean sorted) {
        Map<String, Integer> m = sorted ? new TreeMap<>() : new HashMap<>();
        for (String w : ws) m.put(w, w.length());
        return m;                             // callers see only Map
    }
    // ]]

    public static void main(String[] args) {
        var list = new ArrayList<>(List.of(3, 4));
        System.out.println("before: " + totalBefore(list));

        // [[client
        var words = List.of("kata", "go", "java");
        Map<String, Integer> sizes = lengths(words, true);
        System.out.println(sizes);
        System.out.println("map values: " + total(sizes.values()));
        System.out.println("immutable: " + total(List.of(1, 2, 3)));
        // ]]
    }
}
