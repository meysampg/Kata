import java.util.List;

// [[component
sealed interface Node permits File, Dir {
    String name();
    long size();
}
// ]]

// [[leaf
record File(String name, long size) implements Node {}
// ]]

// [[composite
record Dir(String name, List<Node> children) implements Node {
    Dir(String name, Node... children) {
        this(name, List.of(children));
    }

    public long size() {
        return children.stream().mapToLong(Node::size).sum();
    }
}
// ]]

class Main {
    // [[traverse
    static void print(Node node, int depth) {
        String pad = "  ".repeat(depth);
        switch (node) {
            case File f -> System.out.println(pad + f.name() + " " + f.size());
            case Dir d -> {
                System.out.println(pad + d.name() + "/ " + d.size());
                d.children().forEach(c -> print(c, depth + 1));
            }
        }
    }
    // ]]

    public static void main(String[] args) {
        // [[client
        Node root = new Dir("project",
            new File("README.md", 200),
            new Dir("src",
                new File("Main.java", 700),
                new File("Util.java", 300)),
            new Dir("docs"));
        System.out.println("total = " + root.size());
        print(root, 0);
        // ]]
    }
}
