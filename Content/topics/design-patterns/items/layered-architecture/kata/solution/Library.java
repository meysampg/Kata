import java.util.List;

record Book(String isbn, String title, boolean onLoan) { }

// Callers start here. Keep its signature and behaviour.
final class Library {
    private Library() { }

    static LoanController open(List<Book> books) {
        InMemoryBookRepository repository = new InMemoryBookRepository();
        books.forEach(repository::save);
        return new LoanController(new LoanService(repository));
    }
}
