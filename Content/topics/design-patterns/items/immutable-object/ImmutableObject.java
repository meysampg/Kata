import java.util.ArrayList;
import java.util.List;

record Route(String name, List<String> stops) {
    // [[copy
    Route {
        stops = List.copyOf(stops);
    }
    // ]]

    // [[wither
    Route withStop(String stop) {
        var next = new ArrayList<>(stops);
        next.add(stop);
        return new Route(name, next);
    }
    // ]]
}

class Main {
    // [[shared
    static final Route BASE = new Route("R1", List.of("A", "B"));
    // ]]

    public static void main(String[] args) throws InterruptedException {
        // [[threads
        var results = new Route[3];
        var threads = new ArrayList<Thread>();
        for (int i = 0; i < results.length; i++) {
            int id = i;
            threads.add(Thread.ofVirtual().start(
                () -> results[id] = BASE.withStop("S" + id)));
        }
        for (Thread t : threads) t.join();
        // ]]
        // [[client
        System.out.println(BASE);
        for (Route r : results) System.out.println(r.stops());
        var src = new ArrayList<>(List.of("X"));
        var copy = new Route("tmp", src);
        src.add("Y");
        System.out.println(copy.stops());
        // ]]
    }
}
