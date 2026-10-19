import java.lang.reflect.Field;
import java.lang.reflect.Modifier;
import java.util.LinkedHashMap;
import java.util.Map;

// Given. Stands in for the JSON library: it serializes every field.
final class Json {
    private Json() { }

    static Map<String, Object> fields(Object body) {
        Map<String, Object> out = new LinkedHashMap<>();
        try {
            for (Field f : body.getClass().getDeclaredFields()) {
                if (Modifier.isStatic(f.getModifiers())) continue;
                f.setAccessible(true);
                out.put(f.getName(), f.get(body));
            }
        } catch (IllegalAccessException e) {
            throw new IllegalStateException(e);
        }
        return out;
    }
}
