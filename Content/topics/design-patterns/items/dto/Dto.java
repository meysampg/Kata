import java.util.List;

// [[entity
final class User {
    private final long id;
    private String firstName;
    private String lastName;
    private String email;
    private String passwordHash;
    private List<String> roles;

    User(long id, String first, String last, String email,
         String hash, List<String> roles) {
        this.id = id;
        this.firstName = first;
        this.lastName = last;
        this.email = email;
        this.passwordHash = hash;
        this.roles = roles;
    }

    long id() { return id; }
    String firstName() { return firstName; }
    String lastName() { return lastName; }
    String email() { return email; }
    boolean isAdmin() { return roles.contains("ADMIN"); }
}
// ]]

// [[dtos
record UserSummary(long id, String displayName, boolean admin) {}

record RegisterRequest(String firstName, String lastName, String email) {
    RegisterRequest {
        if (email == null || !email.contains("@")) {
            throw new IllegalArgumentException("email");
        }
    }
}
// ]]

// [[mapper
final class UserMapper {
    static UserSummary toSummary(User u) {
        return new UserSummary(
            u.id(), u.firstName() + " " + u.lastName(), u.isAdmin());
    }

    static User toEntity(long id, RegisterRequest r) {
        return new User(id, r.firstName(), r.lastName(), r.email(),
                "!", List.of("USER"));
    }
}
// ]]

class Main {
    public static void main(String[] args) {
        // [[flow
        var request = new RegisterRequest("Ada", "Lovelace", "ada@x.org");
        User user = UserMapper.toEntity(7, request);
        System.out.println(UserMapper.toSummary(user));
        // ]]
        try {
            new RegisterRequest("Bo", "Ng", "nope");
        } catch (IllegalArgumentException e) {
            System.out.println("rejected: " + e.getMessage());
        }
    }
}
