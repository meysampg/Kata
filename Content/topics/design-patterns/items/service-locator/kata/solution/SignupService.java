// Looks its Mailer up in a locator.
final class SignupService {
    private final Mailer mailer;

    SignupService(ServiceLocator locator) {
        this.mailer = locator.get(Mailer.class);
    }

    void signUp(String email) {
        mailer.send(email, "Welcome");
    }
}
