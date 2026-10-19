// Presentation layer: turns outcomes into status lines.
final class LoanController {
    private final LoanService service;

    LoanController(LoanService service) { this.service = service; }

    String lend(String isbn) {
        try {
            return "200 " + service.lend(isbn).title();
        } catch (IllegalArgumentException e) {
            return "404 " + e.getMessage();
        } catch (IllegalStateException e) {
            return "409 " + e.getMessage();
        }
    }

    String giveBack(String isbn) {
        try {
            return "200 " + service.giveBack(isbn).title();
        } catch (IllegalArgumentException e) {
            return "404 " + e.getMessage();
        } catch (IllegalStateException e) {
            return "409 " + e.getMessage();
        }
    }
}
