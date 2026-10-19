import java.util.Optional;

interface UserStore {
    Optional<String> find(String id);
    void save(String id, String name);
}
