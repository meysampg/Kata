import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.function.BiPredicate;
import java.util.function.Consumer;

// [[observable
final class Observable<T> {
    private final List<Consumer<T>> subscribers = new ArrayList<>();
    private T value;

    Observable(T initial) { this.value = initial; }

    T get() { return value; }

    void set(T next) {
        if (Objects.equals(value, next)) return;
        value = next;
        subscribers.forEach(s -> s.accept(next));
    }

    void bind(Consumer<T> subscriber) {
        subscribers.add(subscriber);
        subscriber.accept(value);
    }
}
// ]]

// [[viewmodel
final class SignInViewModel {
    final Observable<String> email = new Observable<>("");
    final Observable<String> password = new Observable<>("");
    final Observable<Boolean> canSubmit = new Observable<>(false);
    final Observable<String> status = new Observable<>("");
    private final BiPredicate<String, String> auth;

    SignInViewModel(BiPredicate<String, String> auth) {
        this.auth = auth;
        email.bind(e -> refresh());
        password.bind(p -> refresh());
    }

    private void refresh() {
        canSubmit.set(email.get().contains("@")
                && password.get().length() >= 8);
    }

    void submit() {
        if (!canSubmit.get()) return;
        boolean ok = auth.test(email.get(), password.get());
        status.set(ok ? "Welcome" : "Denied");
    }
}
// ]]

class Main {
    public static void main(String[] args) {
        var vm = new SignInViewModel((e, p) -> p.startsWith("hunter"));
        // [[binding
        vm.canSubmit.bind(on -> System.out.println("submit enabled=" + on));
        vm.status.bind(s -> System.out.println("status=" + s));
        // ]]
        // [[input
        vm.email.set("ana@x.org");
        vm.password.set("hunter2");
        vm.password.set("hunter22!");
        vm.submit();
        vm.password.set("x");
        // ]]
    }
}
