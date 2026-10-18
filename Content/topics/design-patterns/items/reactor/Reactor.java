import java.util.EnumMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;

// [[events
enum Op { ACCEPT, READ, CLOSE }

record Ready(String channel, Op op, String data) { }

interface Demultiplexer {
    List<Ready> select();
}
// ]]

// [[reactor
@FunctionalInterface
interface Handler {
    void handle(Ready event);
}

final class Reactor {
    private final Demultiplexer demux;
    private final Map<Op, Handler> handlers = new EnumMap<>(Op.class);

    Reactor(Demultiplexer demux) { this.demux = demux; }

    Reactor on(Op op, Handler handler) {
        handlers.put(op, handler);
        return this;
    }

    void run() {
        List<Ready> batch;
        while (!(batch = demux.select()).isEmpty()) {
            for (Ready event : batch) {
                handlers.get(event.op()).handle(event);
            }
        }
    }
}
// ]]

class Main {
    static Ready ev(String ch, Op op, String data) {
        return new Ready(ch, op, data);
    }

    public static void main(String[] args) {
        var script = List.of(
            List.of(ev("a", Op.ACCEPT, ""), ev("b", Op.ACCEPT, "")),
            List.of(ev("b", Op.READ, "HELLO"), ev("a", Op.READ, "PING")),
            List.of(ev("a", Op.CLOSE, "")),
            List.of(ev("b", Op.READ, "BYE"), ev("b", Op.CLOSE, "")));
        var open = new LinkedHashSet<String>();
        var batches = script.iterator();
        // [[wire
        new Reactor(() -> batches.hasNext() ? batches.next() : List.of())
            .on(Op.ACCEPT, e -> {
                open.add(e.channel());
                System.out.println("accept " + e.channel());
            })
            .on(Op.READ, e -> System.out.println(
                "read " + e.channel() + ": " + e.data().toLowerCase()))
            .on(Op.CLOSE, e -> {
                open.remove(e.channel());
                System.out.println("close " + e.channel() + " open=" + open);
            })
            .run();
        // ]]
    }
}
