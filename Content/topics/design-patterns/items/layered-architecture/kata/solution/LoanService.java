// Business layer: the lending rules, with no idea how they are shown.
final class LoanService {
    private final BookRepository books;

    LoanService(BookRepository books) { this.books = books; }

    Book lend(String isbn) {
        Book book = require(isbn);
        if (book.onLoan()) throw new IllegalStateException("already on loan");
        return store(new Book(isbn, book.title(), true));
    }

    Book giveBack(String isbn) {
        Book book = require(isbn);
        if (!book.onLoan()) throw new IllegalStateException("not on loan");
        return store(new Book(isbn, book.title(), false));
    }

    private Book require(String isbn) {
        Book book = books.find(isbn);
        if (book == null) throw new IllegalArgumentException("unknown book");
        return book;
    }

    private Book store(Book book) {
        books.save(book);
        return book;
    }
}
