import java.util.HashMap;
import java.util.List;
import java.util.Map;

record Book(String isbn, String title, boolean onLoan) { }

// Presentation, business rules and storage all live in this one class.
final class LoanController {
    private final Map<String, Book> rows = new HashMap<>();

    LoanController(List<Book> books) {
        for (Book book : books) {
            rows.put(book.isbn(), book);
        }
    }

    String lend(String isbn) {
        Book book = rows.get(isbn);
        if (book == null) return "404 unknown book";
        if (book.onLoan()) return "409 already on loan";
        rows.put(isbn, new Book(isbn, book.title(), true));
        return "200 " + book.title();
    }

    String giveBack(String isbn) {
        Book book = rows.get(isbn);
        if (book == null) return "404 unknown book";
        if (!book.onLoan()) return "409 not on loan";
        rows.put(isbn, new Book(isbn, book.title(), false));
        return "200 " + book.title();
    }
}

// Callers start here. Keep its signature and behaviour.
final class Library {
    private Library() { }

    static LoanController open(List<Book> books) {
        return new LoanController(books);
    }
}
