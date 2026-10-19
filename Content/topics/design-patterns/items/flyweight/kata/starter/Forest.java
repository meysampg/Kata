import java.util.ArrayList;
import java.util.List;

// Every tree carries its own copy of what it looks like.
final class Tree {
    final int x;
    final int y;
    final String species;
    final String color;
    final Texture texture;

    Tree(int x, int y, String species, String color) {
        this.x = x;
        this.y = y;
        this.species = species;
        this.color = color;
        this.texture = new Texture(species, color);
    }

    String draw() {
        return species + "@" + x + "," + y + " " + color
            + " #" + texture.fingerprint();
    }
}

// Callers use Forest. Keep its signatures and the text draw() returns.
final class Forest {
    private final List<Tree> trees = new ArrayList<>();

    void plant(String species, String color, int x, int y) {
        trees.add(new Tree(x, y, species, color));
    }

    int size() { return trees.size(); }

    String draw(int index) { return trees.get(index).draw(); }
}
