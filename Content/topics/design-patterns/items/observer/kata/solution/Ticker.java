import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;

@FunctionalInterface
interface PriceListener {
    void onChange(String symbol, int oldPrice, int newPrice);
}

final class Ticker {
    /** One subscription; identity, not the listener, is what cancel removes. */
    private static final class Registration {
        final PriceListener listener;

        Registration(PriceListener listener) { this.listener = listener; }
    }

    private final List<Registration> registrations =
        new CopyOnWriteArrayList<>();
    private final String symbol;
    private int price;

    Ticker(String symbol, int price) {
        this.symbol = symbol;
        this.price = price;
    }

    Runnable subscribe(PriceListener listener) {
        var registration = new Registration(listener);
        registrations.add(registration);
        return () -> registrations.remove(registration);
    }

    void set(int newPrice) {
        if (newPrice == price) {
            return;
        }
        int old = price;
        price = newPrice;
        for (Registration r : registrations) {
            r.listener.onChange(symbol, old, newPrice);
        }
    }
}
