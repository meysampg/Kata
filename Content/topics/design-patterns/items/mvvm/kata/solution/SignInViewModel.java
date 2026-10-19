import java.util.function.BiPredicate;

// ViewModel: the screen's state and actions, with no view in sight.
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
