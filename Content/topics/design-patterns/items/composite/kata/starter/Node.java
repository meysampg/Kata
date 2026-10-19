import java.util.Optional;

interface Node {
    String name();

    long size();

    int fileCount();

    // Depth-first, children in order; this node itself is checked first.
    Optional<Node> find(String name);
}
