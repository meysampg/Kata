import java.util.List;
import java.util.Optional;

// A directory: a Node that holds other Nodes.
final class Dir implements Node {
    Dir(String name, Node... children) {
        throw new UnsupportedOperationException("TODO");
    }

    Dir(String name, List<Node> children) {
        throw new UnsupportedOperationException("TODO");
    }

    public String name() {
        throw new UnsupportedOperationException("TODO");
    }

    public long size() {
        throw new UnsupportedOperationException("TODO");
    }

    public int fileCount() {
        throw new UnsupportedOperationException("TODO");
    }

    public Optional<Node> find(String name) {
        throw new UnsupportedOperationException("TODO");
    }
}
