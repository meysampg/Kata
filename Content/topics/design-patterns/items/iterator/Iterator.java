import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Iterator;
import java.util.NoSuchElementException;

// [[aggregate
final class SortedTree<T extends Comparable<T>> implements Iterable<T> {
    private static final class Node<T> {
        final T value;
        Node<T> left, right;
        Node(T value) { this.value = value; }
    }

    private Node<T> root;

    void add(T value) { root = insert(root, value); }

    private Node<T> insert(Node<T> n, T v) {
        if (n == null) return new Node<>(v);
        if (v.compareTo(n.value) < 0) n.left = insert(n.left, v);
        else n.right = insert(n.right, v);
        return n;
    }
// ]]

// [[iterator
    @Override
    public Iterator<T> iterator() {
        return new Iterator<>() {
            private final Deque<Node<T>> path = new ArrayDeque<>();
            { descend(root); }

            private void descend(Node<T> n) {
                for (; n != null; n = n.left) path.push(n);
            }

            public boolean hasNext() { return !path.isEmpty(); }

            public T next() {
                if (path.isEmpty()) throw new NoSuchElementException();
                Node<T> n = path.pop();
                descend(n.right);
                return n.value;
            }
        };
    }
}
// ]]

class Main {
    public static void main(String[] args) {
        var tree = new SortedTree<String>();
        for (String s : "pear fig apple kiwi".split(" ")) tree.add(s);
        // [[client
        StringBuilder sb = new StringBuilder();
        for (String s : tree) sb.append(s).append(' ');
        System.out.println(sb.toString().trim());
        // ]]
        // [[lazy
        Iterator<String> it = tree.iterator();
        System.out.println(it.next() + " " + it.next());
        // ]]
    }
}
