import java.util.ArrayList;
import java.util.List;

// [[template
abstract class Importer<T> {
    public final int run(List<String> lines) {
        open();
        int saved = 0;
        for (String line : lines) {
            T row = parse(line);
            if (!accept(row)) continue;
            store(row);
            saved++;
        }
        close();
        return saved;
    }
// ]]

// [[steps
    protected abstract T parse(String line);
    protected abstract void store(T row);
// ]]

// [[hooks
    protected boolean accept(T row) { return true; }
    protected void open() {}
    protected void close() {}
}
// ]]

record User(String name, int age) {}

// [[concrete
final class UserImporter extends Importer<User> {
    final List<User> saved = new ArrayList<>();

    @Override protected User parse(String line) {
        String[] f = line.split(",");
        return new User(f[0].trim(), Integer.parseInt(f[1].trim()));
    }
    @Override protected void store(User u) { saved.add(u); }
    @Override protected boolean accept(User u) { return u.age() >= 18; }
    @Override protected void open() { System.out.println("open"); }
}
// ]]

class Main {
    public static void main(String[] args) {
        // [[client
        var importer = new UserImporter();
        int n = importer.run(List.of("ana, 31", "kid, 9", "bo, 40"));
        System.out.println("saved " + n);
        System.out.println(importer.saved);
        // ]]
    }
}
