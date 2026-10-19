import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import kata.*;

class CompositeKataTest {
    static Node tree() {
        return new Dir("project",
            new File("README.md", 200),
            new Dir("src",
                new File("Main.java", 700),
                new File("Util.java", 300)),
            new Dir("docs"));
    }

    /** A leaf the learner has never seen. */
    static final class Fixed implements Node {
        public String name() { return "fixed"; }
        public long size() { return 1000; }
        public int fileCount() { return 7; }
        public Optional<Node> find(String n) { return Optional.empty(); }
    }

    @Check(id = "size-sums-recursively")
    void sizeSumsRecursively() {
        Expect.equal(1200L, tree().size(), "size of the whole tree");
        Expect.equal(1000L, ((Dir) tree().find("src").get()).size(), "size of src");
    }

    @Check(id = "empty-dir")
    void emptyDir() {
        Dir empty = new Dir("docs");
        Expect.equal(0L, empty.size(), "size of an empty Dir");
        Expect.equal(0, empty.fileCount(), "fileCount of an empty Dir");
        Expect.equal("docs", empty.name(), "name of the Dir");
    }

    @Check(id = "file-count")
    void fileCount() {
        Expect.equal(3, tree().fileCount(), "files in the whole tree");
        Dir nested = new Dir("a", new Dir("b", new Dir("c", new File("x", 1))));
        Expect.equal(1, nested.fileCount(), "files under three nested Dirs");
    }

    @Check(id = "find-by-name")
    void findByName() {
        Node root = tree();
        Expect.equal("Util.java", root.find("Util.java").orElseThrow().name(), "find a nested file");
        Expect.equal("src", root.find("src").orElseThrow().name(), "find a Dir");
        Expect.equal("project", root.find("project").orElseThrow().name(), "find the root itself");
        Expect.isTrue(root.find("nope").isEmpty(), "find of a missing name should be empty");
    }

    @Check(id = "find-first-match")
    void findFirstMatch() {
        Node root = new Dir("r",
            new Dir("a", new File("same", 1)),
            new File("same", 2));
        Expect.equal(1L, root.find("same").orElseThrow().size(),
            "find should be depth-first and in order");
    }

    @Check(id = "dir-copies-its-children")
    void dirCopiesItsChildren() {
        List<Node> kids = new ArrayList<>(List.of(new File("a", 5)));
        Dir dir = new Dir("d", kids);
        kids.add(new File("b", 6));
        Expect.equal(5L, dir.size(), "a Dir should keep its own copy of the list");
        Expect.equal(1, dir.fileCount(), "fileCount after the caller changed its list");
    }

    @Check(id = "dir-is-a-node", kind = Kind.DESIGN)
    void dirIsANode() {
        Class<?> dir = Types.named("Dir");
        Expect.isTrue(Node.class.isAssignableFrom(dir), "Dir should implement Node");
        Expect.isTrue(!Types.fieldsOfType(dir, List.class).isEmpty(),
            "Dir should hold its children in a List<Node>");
    }

    @Check(id = "dir-treats-children-alike", kind = Kind.DESIGN)
    void dirTreatsChildrenAlike() {
        var dir = Source.type("Dir");
        Expect.none(dir.instanceofs(), "Dir asks what kind of Node a child is");
        Expect.none(dir.switches(), "Dir switches on the kind of child");
        Expect.none(dir.mentions("File"), "Dir should not know about File");
    }

    @Check(id = "any-node-fits-inside", kind = Kind.DESIGN)
    void anyNodeFitsInside() {
        Dir dir = new Dir("odd", new Fixed(), new File("f", 1), new Dir("in", new Fixed()));
        Expect.equal(2001L, dir.size(), "size with a Node type Dir has never seen");
        Expect.equal(15, dir.fileCount(), "fileCount with a Node type Dir has never seen");
    }
}
