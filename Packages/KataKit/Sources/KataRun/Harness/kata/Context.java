package kata;

import com.sun.source.tree.CompilationUnitTree;
import com.sun.source.util.SourcePositions;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/** State the harness shares with {@link Types} and {@link Source}. Not for test code. */
public final class Context {
    /** One parsed source file of the learner. */
    public record Unit(String fileName, CompilationUnitTree tree, SourcePositions positions) {}

    private static volatile ClassLoader loader;
    private static volatile List<Unit> units = List.of();
    private static volatile Map<String, String> typeNames = Map.of();

    private Context() {}

    public static void install(ClassLoader classLoader, List<Unit> userUnits, Map<String, String> userTypes) {
        loader = classLoader;
        units = List.copyOf(userUnits);
        typeNames = Map.copyOf(userTypes);
    }

    static List<Unit> units() {
        return units;
    }

    static ClassLoader loader() {
        return loader;
    }

    /** Resolves a type declared in the learner's files by simple or binary name. */
    static Class<?> findUserType(String name) {
        String binary = typeNames.get(name);
        if (binary == null || loader == null) {
            return null;
        }
        try {
            return Class.forName(binary, false, loader);
        } catch (ClassNotFoundException | LinkageError e) {
            return null;
        }
    }

    /** Collects simple name -> binary name for every class declared in the units. */
    public static Map<String, String> collectTypeNames(List<Unit> userUnits) {
        Map<String, String> out = new HashMap<>();
        List<String> ambiguous = new ArrayList<>();
        for (Unit u : userUnits) {
            String pkg = u.tree().getPackageName() == null ? "" : u.tree().getPackageName() + ".";
            new com.sun.source.util.TreeScanner<Void, String>() {
                @Override
                public Void visitClass(com.sun.source.tree.ClassTree node, String outer) {
                    String simple = node.getSimpleName().toString();
                    if (!simple.isEmpty()) {
                        String binary = outer == null ? pkg + simple : outer + "$" + simple;
                        out.put(binary, binary);
                        if (outer == null) {
                            out.put(simple, binary);
                        } else if (out.containsKey(simple)) {
                            ambiguous.add(simple);
                        } else {
                            out.put(simple, binary);
                        }
                        return super.visitClass(node, binary);
                    }
                    return super.visitClass(node, outer);
                }
            }.scan(u.tree(), null);
        }
        for (String a : ambiguous) {
            out.remove(a);
        }
        return out;
    }
}
