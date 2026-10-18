import java.util.ArrayList;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

// [[flyweight
record TreeType(String species, String color) {
    String draw(int x, int y) { return species + "@" + x + "," + y; }
}
// ]]

// [[factory
final class TreeTypes {
    private static final Map<TreeType, TreeType> POOL =
        new ConcurrentHashMap<>();

    static TreeType of(String species, String color) {
        return POOL.computeIfAbsent(new TreeType(species, color), t -> t);
    }

    static int size() { return POOL.size(); }
}
// ]]

// [[context
record Tree(int x, int y, TreeType type) {
    String draw() { return type.draw(x, y); }
}
// ]]

class Main {
    public static void main(String[] args) {
        // [[client
        var forest = new ArrayList<Tree>();
        String[] species = {"oak", "pine"};
        for (int i = 0; i < 6; i++) {
            String s = species[i % 2];
            String color = s.equals("oak") ? "green" : "dark";
            forest.add(new Tree(i * 10, i * 5, TreeTypes.of(s, color)));
        }
        // ]]
        // [[check
        System.out.println(forest.size() + " trees, "
            + TreeTypes.size() + " shared types");
        System.out.println(forest.get(0).type() == forest.get(2).type());
        System.out.println(forest.get(3).draw());
        // ]]
    }
}
