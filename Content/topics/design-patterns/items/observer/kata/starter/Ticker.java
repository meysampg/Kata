import java.util.ArrayList;
import java.util.List;

@FunctionalInterface
interface PriceListener {
    void onChange(String symbol, int oldPrice, int newPrice);
}

// Listeners come and go at any time, even from inside a notification.
final class Ticker {
    private final List<PriceListener> listeners = new ArrayList<>();
    private final String symbol;
    private int price;

    Ticker(String symbol, int price) {
        this.symbol = symbol;
        this.price = price;
    }

    Runnable subscribe(PriceListener listener) {
        listeners.add(listener);
        return () -> listeners.remove(listener);
    }

    void set(int newPrice) {
        if (newPrice == price) {
            return;
        }
        int old = price;
        price = newPrice;
        for (PriceListener l : listeners) {
            l.onChange(symbol, old, newPrice);
        }
    }
}
