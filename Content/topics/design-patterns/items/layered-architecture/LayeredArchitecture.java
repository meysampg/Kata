import java.util.HashMap;
import java.util.Map;

// [[domain
record Book(String isbn, String title, boolean onLoan) {}
// ]]

// [[data
interface BookRepository {
    Book find(String isbn);
    void save(Book book);
}

final class InMemoryBookRepository implements BookRepository {
    private final Map<String, Book> rows = new HashMap<>();

    public Book find(String isbn) { return rows.get(isbn); }
    public void save(Book book) { rows.put(book.isbn(), book); }
}
// ]]

// [[service
final class LoanService {
    private final BookRepository books;

    LoanService(BookRepository books) { this.books = books; }

    Book lend(String isbn) {
        Book book = books.find(isbn);
        if (book == null) throw new IllegalArgumentException("unknown book");
        if (book.onLoan()) throw new IllegalStateException("already on loan");
        Book lent = new Book(book.isbn(), book.title(), true);
        books.save(lent);
        return lent;
    }
}
// ]]

// [[presentation
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
}
// ]]

class Main {
    public static void main(String[] args) {
        // [[wiring
        var books = new InMemoryBookRepository();
        books.save(new Book("111", "Refactoring", false));
        var controller = new LoanController(new LoanService(books));
        // ]]
        System.out.println(controller.lend("111"));
        System.out.println(controller.lend("111"));
        System.out.println(controller.lend("999"));
    }
}
