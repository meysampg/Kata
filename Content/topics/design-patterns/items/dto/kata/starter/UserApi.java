import java.util.ArrayList;
import java.util.List;

final class User {
    private final long id;
    private final String firstName;
    private final String lastName;
    private final String email;
    private final String passwordHash;
    private final List<String> roles;

    User(long id, String firstName, String lastName, String email,
         String passwordHash, List<String> roles) {
        this.id = id;
        this.firstName = firstName;
        this.lastName = lastName;
        this.email = email;
        this.passwordHash = passwordHash;
        this.roles = roles;
    }

    long id() { return id; }
    String firstName() { return firstName; }
    String lastName() { return lastName; }
    String email() { return email; }
    boolean isAdmin() { return roles.contains("ADMIN"); }
}

// Sent by clients to register.
record RegisterRequest(String firstName, String lastName, String email) { }

// The public API. What it returns is what goes over the wire.
final class UserApi {
    private final List<User> users = new ArrayList<>(List.of(
        new User(7, "Ada", "Lovelace", "ada@x.org", "bcrypt:9f2c",
            List.of("ADMIN", "USER")),
        new User(8, "Bo", "Ng", "bo@x.org", "bcrypt:41aa", List.of("USER"))));

    User show(long id) {
        return users.stream().filter(u -> u.id() == id).findFirst()
            .orElseThrow(() -> new IllegalArgumentException("no user " + id));
    }

    List<User> list() {
        return List.copyOf(users);
    }

    long register(RegisterRequest request) {
        long id = 9 + users.size() - 2;
        users.add(new User(id, request.firstName(), request.lastName(),
            request.email(), "bcrypt:new", List.of("USER")));
        return id;
    }
}
