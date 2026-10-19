record Expense(String employee, String category, long cents) { }

// Every new rule means finding the right place inside these nested ifs.
final class ApprovalService {
    // Callers use this. Keep its signature and replies.
    String approve(Expense e) {
        if (e.category().equals("gift")) {
            if (e.cents() > 5_000) {
                return "rejected:policy";
            } else {
                return "approved:auto";
            }
        } else {
            if (e.cents() <= 10_000) {
                return "approved:auto";
            } else {
                if (e.cents() <= 100_000) {
                    return "approved:manager";
                } else {
                    if (e.cents() <= 1_000_000) {
                        return "approved:director";
                    }
                }
            }
        }
        return "escalate:board";
    }
}
