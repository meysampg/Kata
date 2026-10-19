import java.util.HashSet;
import java.util.Set;

// Adapters: infrastructure plugged into the ports.
final class MemoryUserStore implements UserStore {
    private final Set<String> emails = new HashSet<>();

    public boolean exists(String email) { return emails.contains(email); }

    public void add(String email) { emails.add(email); }
}

final class SmtpMailer implements Mailer {
    public void send(String to, String body) { SmtpClient.send(to, body); }
}
