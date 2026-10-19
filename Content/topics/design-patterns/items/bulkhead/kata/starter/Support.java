@SuppressWarnings("serial")
class BulkheadFullException extends RuntimeException {
    BulkheadFullException(String name) { super(name + " is full"); }
}
