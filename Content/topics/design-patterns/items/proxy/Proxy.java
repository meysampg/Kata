import java.lang.reflect.Proxy;
import java.util.Set;
import java.util.function.Supplier;

// [[subject
interface Documents {
    String read(String id);
}
// ]]

// [[real
final class RemoteDocuments implements Documents {
    RemoteDocuments() { System.out.println("connect"); }

    public String read(String id) { return "body of " + id; }
}
// ]]

// [[proxy
final class GuardedDocuments implements Documents {
    private final Supplier<Documents> factory;
    private final Set<String> allowed;
    private Documents real; // created on first use

    GuardedDocuments(Supplier<Documents> factory, Set<String> allowed) {
        this.factory = factory;
        this.allowed = allowed;
    }

    public String read(String id) {
        if (!allowed.contains(id)) throw new SecurityException("denied: " + id);
        if (real == null) real = factory.get();
        return real.read(id);
    }
}
// ]]

class Main {
    public static void main(String[] args) {
        // [[client
        Documents docs =
            new GuardedDocuments(RemoteDocuments::new, Set.of("a1"));
        System.out.println("proxy ready");
        System.out.println(docs.read("a1"));
        System.out.println(docs.read("a1"));
        try {
            docs.read("x9");
        } catch (SecurityException e) {
            System.out.println(e.getMessage());
        }
        // ]]
        // [[dynamic
        Documents logged = (Documents) Proxy.newProxyInstance(
            Documents.class.getClassLoader(),
            new Class<?>[] {Documents.class},
            (proxy, method, a) -> {
                System.out.println("-> " + method.getName());
                return method.invoke(docs, a);
            });
        System.out.println(logged.read("a1"));
        // ]]
    }
}
