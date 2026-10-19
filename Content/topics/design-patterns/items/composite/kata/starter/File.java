import java.util.Optional;

record File(String name, long size) implements Node {
    public int fileCount() { return 1; }

    public Optional<Node> find(String wanted) {
        return name.equals(wanted) ? Optional.of(this) : Optional.empty();
    }
}
