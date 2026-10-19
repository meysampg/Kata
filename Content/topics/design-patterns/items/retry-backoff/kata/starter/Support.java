import java.time.Duration;

@SuppressWarnings("serial")
class TransientException extends RuntimeException {
    TransientException(String message) { super(message); }
}

@SuppressWarnings("serial")
class PermanentException extends RuntimeException {
    PermanentException(String message) { super(message); }
}

interface Sleeper {
    void sleep(Duration d);
}
