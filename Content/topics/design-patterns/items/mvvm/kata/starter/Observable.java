import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.function.Consumer;

// Given. A value holder that tells subscribers when the value changes.
final class Observable<T> {
    private final List<Consumer<T>> subscribers = new ArrayList<>();
    private T value;

    Observable(T initial) { this.value = initial; }

    T get() { return value; }

    // Does nothing when the value is equal to the current one.
    void set(T next) {
        if (Objects.equals(value, next)) return;
        value = next;
        for (Consumer<T> s : List.copyOf(subscribers)) s.accept(next);
    }

    // Calls the subscriber now with the current value, then on every change.
    void bind(Consumer<T> subscriber) {
        subscribers.add(subscriber);
        subscriber.accept(value);
    }
}
