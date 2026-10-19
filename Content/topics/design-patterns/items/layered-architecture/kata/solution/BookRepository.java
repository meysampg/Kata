import java.util.HashMap;
import java.util.Map;

// Data layer.
interface BookRepository {
    Book find(String isbn);

    void save(Book book);
}

final class InMemoryBookRepository implements BookRepository {
    private final Map<String, Book> rows = new HashMap<>();

    public Book find(String isbn) { return rows.get(isbn); }

    public void save(Book book) { rows.put(book.isbn(), book); }
}
