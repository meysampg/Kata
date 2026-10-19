import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.util.ArrayList;
import java.util.List;
import kata.*;

class TellDontAskKataTest {
    @Check(id = "withdraw-within-balance")
    void withdrawWithinBalance() {
        Account a = new Account(100, 0);
        Expect.isTrue(new Teller().withdraw(a, 40), "a withdrawal within the balance should succeed");
        Expect.equal(60L, a.getBalance(), "balance after withdrawing 40");
    }

    @Check(id = "overdraft-allowed")
    void overdraftAllowed() {
        Account a = new Account(100, 50);
        Expect.isTrue(new Teller().withdraw(a, 150), "100 plus a 50 overdraft covers 150");
        Expect.equal(-50L, a.getBalance(), "balance after using the overdraft");
    }

    @Check(id = "rejected-withdrawal-changes-nothing")
    void rejectedWithdrawalChangesNothing() {
        Account a = new Account(100, 50);
        Expect.isTrue(!new Teller().withdraw(a, 151), "151 exceeds balance plus overdraft");
        Expect.equal(100L, a.getBalance(), "balance after a rejected withdrawal");
    }

    @Check(id = "transfer-moves-money")
    void transferMovesMoney() {
        Account from = new Account(100, 0);
        Account to = new Account(5, 0);
        Expect.isTrue(new Teller().transfer(from, to, 70), "the transfer should succeed");
        Expect.equal(30L, from.getBalance(), "source balance");
        Expect.equal(75L, to.getBalance(), "target balance");
    }

    @Check(id = "failed-transfer-changes-nothing")
    void failedTransferChangesNothing() {
        Account from = new Account(10, 0);
        Account to = new Account(5, 0);
        Expect.isTrue(!new Teller().transfer(from, to, 11), "the transfer should be refused");
        Expect.equal(10L, from.getBalance(), "source balance");
        Expect.equal(5L, to.getBalance(), "target balance");
    }

    @Check(id = "account-owns-the-rules", kind = Kind.DESIGN)
    void accountOwnsTheRules() {
        Class<?> account = Types.named("Account");
        Method withdraw = Types.method(account, "withdraw", long.class);
        Expect.equal(boolean.class, withdraw.getReturnType(), "Account.withdraw's return type");
        Types.method(account, "deposit", long.class);
    }

    @Check(id = "no-raw-state-exposed", kind = Kind.DESIGN)
    void noRawStateExposed() {
        List<String> leaks = new ArrayList<>();
        for (Method m : Types.named("Account").getDeclaredMethods()) {
            String n = m.getName();
            if (n.equals("setBalance") || n.equals("getOverdraft") || n.equals("overdraft")) {
                leaks.add(n);
            }
        }
        Expect.isTrue(leaks.isEmpty(), "Account still hands out its internals: " + leaks);
    }

    @Check(id = "teller-does-not-ask", kind = Kind.DESIGN)
    void tellerDoesNotAsk() {
        var teller = Source.type("Teller");
        Expect.none(teller.calls("getBalance"), "Teller still asks for the balance");
        Expect.none(teller.calls("getOverdraft"), "Teller still asks for the overdraft");
        Expect.none(teller.calls("setBalance"), "Teller still writes the balance back");
    }
}
