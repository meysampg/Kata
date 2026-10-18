import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;

// [[observer
@FunctionalInterface
interface PriceListener {
    void onChange(String symbol, int oldPrice, int newPrice);
}
// ]]

// [[subject
final class Ticker {
    private final List<PriceListener> listeners = new CopyOnWriteArrayList<>();
    private final String symbol;
    private int price;

    Ticker(String symbol, int price) {
        this.symbol = symbol;
        this.price = price;
    }

    Runnable subscribe(PriceListener l) {
        listeners.add(l);
        return () -> listeners.remove(l);
    }

    void set(int newPrice) {
        if (newPrice == price) return;
        int old = price;
        price = newPrice;
        for (PriceListener l : listeners) l.onChange(symbol, old, newPrice);
    }
}
// ]]

class Main {
    public static void main(String[] args) {
        var ticker = new Ticker("ACME", 100);
        var log = new ArrayList<String>();
        // [[subscribe
        Runnable cancelLog = ticker.subscribe(
            (s, o, n) -> log.add(s + " " + o + "->" + n));
        ticker.subscribe((s, o, n) -> {
            if (n > 110) System.out.println("ALERT " + s + " at " + n);
        });
        // ]]
        ticker.set(105);
        ticker.set(120);
        // [[unsubscribe
        cancelLog.run();
        ticker.set(90);
        // ]]
        System.out.println(log);
    }
}
