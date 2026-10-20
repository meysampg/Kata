import java.lang.reflect.Field;
import java.lang.reflect.Modifier;
import java.util.ArrayList;
import java.util.List;
import kata.*;

class MvvmKataTest {
    @Check(id = "starts-disabled")
    void startsDisabled() {
        var vm = new SignInViewModel((e, p) -> true);
        Expect.equal(false, vm.canSubmit.get(), "canSubmit at the start");
        Expect.equal("", vm.status.get(), "status at the start");
    }

    @Check(id = "can-submit-rule")
    void canSubmitRule() {
        var vm = new SignInViewModel((e, p) -> true);
        vm.email.set("ana@x.org");
        Expect.equal(false, vm.canSubmit.get(), "email only");
        vm.password.set("1234567");
        Expect.equal(false, vm.canSubmit.get(), "7-character password");
        vm.password.set("12345678");
        Expect.equal(true, vm.canSubmit.get(), "8-character password");
        vm.email.set("ana");
        Expect.equal(false, vm.canSubmit.get(), "email without @");
    }

    @Check(id = "bindings-see-changes")
    void bindingsSeeChanges() {
        var vm = new SignInViewModel((e, p) -> true);
        List<Boolean> seen = new ArrayList<>();
        vm.canSubmit.bind(seen::add);
        vm.email.set("a@x");
        vm.password.set("12345678");
        vm.password.set("123456789");
        vm.password.set("x");
        Expect.equal(List.of(false, true, false), seen, "values a view bound to canSubmit saw");
    }

    @Check(id = "submit-reports-outcome")
    void submitReportsOutcome() {
        var vm = new SignInViewModel((e, p) -> p.startsWith("hunter"));
        vm.email.set("ana@x.org");
        vm.password.set("wrongwrong");
        vm.submit();
        Expect.equal("Denied", vm.status.get(), "status after a bad password");
        vm.password.set("hunter22!");
        vm.submit();
        Expect.equal("Welcome", vm.status.get(), "status after a good password");
    }

    @Check(id = "invalid-form-is-not-sent")
    void invalidFormIsNotSent() {
        List<String> calls = new ArrayList<>();
        var vm = new SignInViewModel((e, p) -> calls.add(e));
        vm.email.set("ana@x.org");
        vm.password.set("short");
        vm.submit();
        Expect.equal(List.of(), calls, "authentication calls for an invalid form");
        Expect.equal("", vm.status.get(), "status after an ignored submit");
    }

    @Check(id = "state-is-observable", kind = Kind.DESIGN)
    void stateIsObservable() {
        Class<?> vm = Types.named("SignInViewModel");
        for (String name : List.of("email", "password", "canSubmit", "status")) {
            Field f;
            try {
                f = vm.getDeclaredField(name);
            } catch (NoSuchFieldException e) {
                Expect.fail("SignInViewModel needs a field named " + name);
                return;
            }
            Expect.isTrue(f.getType() == Observable.class,
                "SignInViewModel." + name + " should be an Observable");
            Expect.isTrue(!Modifier.isPrivate(f.getModifiers()) && Modifier.isFinal(f.getModifiers()),
                "SignInViewModel." + name + " should be final and visible to a view");
        }
    }

    @Check(id = "viewmodel-knows-no-view", kind = Kind.DESIGN)
    void viewmodelKnowsNoView() {
        for (Field f : Types.named("SignInViewModel").getDeclaredFields()) {
            String type = f.getType().getName();
            Expect.isTrue(f.getType() == Observable.class || type.startsWith("java."),
                "SignInViewModel." + f.getName() + " has type " + type
                + ", which looks like a view or toolkit type");
        }
        var source = Source.type("SignInViewModel");
        Expect.none(source.mentions("System"), "SignInViewModel prints instead of exposing state");
        Expect.none(source.calls("println"), "SignInViewModel prints instead of exposing state");
        Expect.none(source.mentions("Thread"), "SignInViewModel manages threads of its own");
    }

    @Check(id = "derived-state-is-computed-once", kind = Kind.DESIGN)
    void derivedStateIsComputedOnce() {
        var vm = Source.type("SignInViewModel");
        Expect.none(vm.mentions("Timer"), "SignInViewModel polls instead of reacting");
        var submit = vm.method("submit");
        Expect.isTrue(!submit.fieldReads("canSubmit").isEmpty(),
            "submit() should gate on the derived canSubmit state instead of deciding again");
        Expect.none(submit.calls("contains"),
            "submit() re-checks the email rule; canSubmit already holds the answer");
        Expect.none(submit.calls("length"),
            "submit() re-checks the password rule; canSubmit already holds the answer");
    }
}
