import java.util.function.BiPredicate;

// ViewModel: the screen's state and actions, with no view in sight.
final class SignInViewModel {
    final Observable<String> email = new Observable<>("");
    final Observable<String> password = new Observable<>("");
    final Observable<Boolean> canSubmit = new Observable<>(false);
    final Observable<String> status = new Observable<>("");

    SignInViewModel(BiPredicate<String, String> auth) {
        throw new UnsupportedOperationException("TODO");
    }

    void submit() {
        throw new UnsupportedOperationException("TODO");
    }
}
