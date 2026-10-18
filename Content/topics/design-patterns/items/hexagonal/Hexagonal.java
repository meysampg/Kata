import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

// [[ports
interface RegisterUser {
    String register(String email);
}

interface UserStore {
    boolean exists(String email);
    void add(String email);
}

interface Mailer {
    void welcome(String email);
}
// ]]

// [[core
final class Registration implements RegisterUser {
    private final UserStore store;
    private final Mailer mailer;

    Registration(UserStore store, Mailer mailer) {
        this.store = store;
        this.mailer = mailer;
    }

    public String register(String email) {
        if (!email.contains("@")) return "invalid";
        if (store.exists(email)) return "duplicate";
        store.add(email);
        mailer.welcome(email);
        return "registered";
    }
}
// ]]

// [[adapters
final class MemoryUserStore implements UserStore {
    private final Set<String> emails = new HashSet<>();

    public boolean exists(String email) { return emails.contains(email); }
    public void add(String email) { emails.add(email); }
}

final class RecordingMailer implements Mailer {
    final List<String> sent = new ArrayList<>();

    public void welcome(String email) { sent.add(email); }
}
// ]]

class Main {
    public static void main(String[] args) {
        var mailer = new RecordingMailer();
        // [[assembly
        RegisterUser app = new Registration(new MemoryUserStore(), mailer);
        // ]]
        // [[driver
        for (String line : List.of("ana@x.org", "bad", "ana@x.org")) {
            System.out.println(line + " -> " + app.register(line));
        }
        // ]]
        System.out.println("mails: " + mailer.sent);
    }
}
