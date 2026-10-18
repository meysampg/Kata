// [[state
final class Counter {
    private int n;
    void inc() { n++; }
    int value() { return n; }
}
// ]]

class Main {
    public static void main(String[] args) {
        // [[make
        Counter c = new Counter();
        // ]]
        // [[run
        c.inc();
        c.inc();
        // ]]
        // [[print
        System.out.println(c.value());
        // ]]
    }
}
