import java.util.List;

enum Op { ACCEPT, READ, CLOSE }

record Ready(String channel, Op op, String data) { }

/** Blocks until something is ready; an empty list means "no more events". */
interface Demultiplexer {
    List<Ready> select();
}

@FunctionalInterface
interface Handler {
    void handle(Ready event);
}
