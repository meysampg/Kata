import java.util.List;
import java.util.Optional;

final class Dir implements Node {
    private final String name;
    private final List<Node> children;

    Dir(String name, Node... children) {
        this(name, List.of(children));
    }

    Dir(String name, List<Node> children) {
        this.name = name;
        this.children = List.copyOf(children);
    }

    public String name() { return name; }

    public long size() {
        return children.stream().mapToLong(Node::size).sum();
    }

    public int fileCount() {
        return children.stream().mapToInt(Node::fileCount).sum();
    }

    public Optional<Node> find(String wanted) {
        if (name.equals(wanted)) return Optional.of(this);
        for (Node child : children) {
            Optional<Node> hit = child.find(wanted);
            if (hit.isPresent()) return hit;
        }
        return Optional.empty();
    }
}
