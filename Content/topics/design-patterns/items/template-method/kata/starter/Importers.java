import java.util.ArrayList;
import java.util.List;

record User(String name, int age) { }

// Two importers repeat the same skeleton and differ only in the format.
final class CsvImporter {
    private final List<User> saved = new ArrayList<>();
    private final List<String> log = new ArrayList<>();

    int run(List<String> lines) {
        log.add("open");
        int count = 0;
        try {
            for (String line : lines) {
                if (line.isBlank()) {
                    continue;
                }
                String[] f = line.split(",");
                User u = new User(f[0].trim(), Integer.parseInt(f[1].trim()));
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

    List<User> saved() { return saved; }

    List<String> log() { return log; }
}

final class PipeImporter {
    private final List<User> saved = new ArrayList<>();
    private final List<String> log = new ArrayList<>();

    int run(List<String> lines) {
        log.add("open");
        int count = 0;
        try {
            for (String line : lines) {
                if (line.isBlank() || line.startsWith("#")) {
                    continue;
                }
                String[] f = line.split("\\|");
                User u = new User(f[0].trim(), Integer.parseInt(f[1].trim()));
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

    List<User> saved() { return saved; }

    List<String> log() { return log; }
}
