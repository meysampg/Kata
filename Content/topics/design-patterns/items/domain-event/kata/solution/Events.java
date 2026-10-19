import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Consumer;

record PatientDischarged(String patientId, String bedId) { }

final class EventBus {
    private final Map<Class<?>, List<Consumer<Object>>> handlers =
        new HashMap<>();

    <E> void on(Class<E> type, Consumer<E> handler) {
        handlers.computeIfAbsent(type, t -> new ArrayList<>())
            .add(e -> handler.accept(type.cast(e)));
    }

    void publish(List<?> events) {
        for (Object e : events) {
            handlers.getOrDefault(e.getClass(), List.of())
                .forEach(h -> h.accept(e));
        }
    }
}
