import java.util.ArrayList;
import java.util.List;

record User(String name, int age) { }

abstract class Importer {
    private final List<User> saved = new ArrayList<>();
    private final List<String> log = new ArrayList<>();

    final int run(List<String> lines) {
        log.add("open");
        int count = 0;
        try {
            for (String line : lines) {
                if (line.isBlank() || ignore(line)) {
                    continue;
                }
                User u = parse(line);
                if (u.age() < 18) {
                    log.add("skip " + u.name());
                    continue;
                }
                saved.add(u);
                count++;
            }
            log.add("saved " + count);
            return count;
        } finally {
            log.add("close");
        }
    }

    protected abstract User parse(String line);

    protected boolean ignore(String line) {
        return false;
    }

    List<User> saved() { return saved; }

    List<String> log() { return log; }
}

final class CsvImporter extends Importer {
    @Override
    protected User parse(String line) {
        String[] f = line.split(",");
        return new User(f[0].trim(), Integer.parseInt(f[1].trim()));
    }
}

final class PipeImporter extends Importer {
    @Override
    protected boolean ignore(String line) {
        return line.startsWith("#");
    }

    @Override
    protected User parse(String line) {
        String[] f = line.split("\\|");
        return new User(f[0].trim(), Integer.parseInt(f[1].trim()));
    }
}
