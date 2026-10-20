import java.util.EnumMap;
import java.util.List;
import java.util.Map;

final class Reactor {
    private final Demultiplexer demux;
    private final Map<Op, Handler> handlers = new EnumMap<>(Op.class);
    // volatile: stop() may also be called from another thread.
    private volatile boolean stopped;

    Reactor(Demultiplexer demux) {
        this.demux = demux;
    }

    Reactor on(Op op, Handler handler) {
        handlers.put(op, handler);
        return this;
    }

    void run() {
        stopped = false;
        List<Ready> batch;
        while (!stopped && !(batch = demux.select()).isEmpty()) {
            for (Ready event : batch) {
                Handler handler = handlers.get(event.op());
                if (handler == null) {
                    throw new IllegalStateException(
                        "no handler for " + event.op());
                }
                handler.handle(event);
            }
        }
    }

    void stop() {
        stopped = true;
    }
}
