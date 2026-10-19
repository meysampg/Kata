import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

// Shared: what a kind of tree looks like.
record TreeType(String species, String color, Texture texture) {
    String draw(int x, int y) {
        return species + "@" + x + "," + y + " " + color
            + " #" + texture.fingerprint();
    }
}

final class TreeTypes {
    private static final Map<String, TreeType> POOL =
        new ConcurrentHashMap<>();

    private TreeTypes() { }

    static TreeType of(String species, String color) {
        return POOL.computeIfAbsent(species + "/" + color,
            k -> new TreeType(species, color, new Texture(species, color)));
    }
}

// Per tree: only where it stands.
record Tree(int x, int y, TreeType type) {
    String draw() { return type.draw(x, y); }
}

final class Forest {
    private final List<Tree> trees = new ArrayList<>();

    void plant(String species, String color, int x, int y) {
        trees.add(new Tree(x, y, TreeTypes.of(species, color)));
    }

    int size() { return trees.size(); }

    String draw(int index) { return trees.get(index).draw(); }
}
