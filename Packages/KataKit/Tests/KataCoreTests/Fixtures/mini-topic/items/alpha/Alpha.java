// [[iface
interface Greeter {
    String greet(String name);
}
// ]]

// [[impl
final class Polite implements Greeter {
    public String greet(String name) { return "Hello, " + name; }
}
// ]]

class Main {
    public static void main(String[] args) {
        // [[use
        Greeter g = new Polite();
        System.out.println(g.greet("Kata"));
        // ]]
    }
}
