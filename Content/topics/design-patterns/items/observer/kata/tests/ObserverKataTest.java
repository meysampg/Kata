import java.util.ArrayList;
import java.util.List;
import kata.*;

class ObserverKataTest {
    static PriceListener logTo(List<String> log, String name) {
        return (s, o, n) -> log.add(name + " " + o + "->" + n);
    }

    @Check(id = "delivers-in-order")
    void deliversInOrder() {
        var ticker = new Ticker("ACME", 100);
        List<String> log = new ArrayList<>();
        ticker.subscribe(logTo(log, "a"));
        ticker.subscribe(logTo(log, "b"));
        ticker.set(105);
        Expect.equal(List.of("a 100->105", "b 100->105"), log, "one change");
    }

    @Check(id = "unchanged-price-is-silent")
    void unchangedPriceIsSilent() {
        var ticker = new Ticker("ACME", 100);
        List<String> log = new ArrayList<>();
        ticker.subscribe(logTo(log, "a"));
        ticker.set(100);
        Expect.equal(List.of(), log, "setting the same price");
    }

    @Check(id = "cancel-stops-delivery")
    void cancelStopsDelivery() {
        var ticker = new Ticker("ACME", 100);
        List<String> log = new ArrayList<>();
        Runnable cancel = ticker.subscribe(logTo(log, "a"));
        ticker.subscribe(logTo(log, "b"));
        ticker.set(101);
        cancel.run();
        ticker.set(102);
        Expect.equal(List.of("a 100->101", "b 100->101", "b 101->102"), log,
            "deliveries around a cancel");
    }

    @Check(id = "cancel-during-notify")
    void cancelDuringNotify() {
        var ticker = new Ticker("ACME", 100);
        List<String> log = new ArrayList<>();
        Runnable[] cancelFirst = new Runnable[1];
        cancelFirst[0] = ticker.subscribe((s, o, n) -> {
            log.add("once " + n);
            cancelFirst[0].run();
        });
        ticker.subscribe(logTo(log, "b"));
        ticker.subscribe(logTo(log, "c"));
        ticker.set(101);
        ticker.set(102);
        Expect.equal(List.of("once 101", "b 100->101", "c 100->101",
                "b 101->102", "c 101->102"), log,
            "a listener that unsubscribes itself while being notified");
    }

    @Check(id = "subscribe-during-notify")
    void subscribeDuringNotify() {
        var ticker = new Ticker("ACME", 100);
        List<String> log = new ArrayList<>();
        boolean[] added = new boolean[1];
        ticker.subscribe((s, o, n) -> {
            log.add("first " + n);
            if (!added[0]) {
                added[0] = true;
                ticker.subscribe(logTo(log, "late"));
            }
        });
        ticker.set(101);
        ticker.set(102);
        Expect.equal(List.of("first 101", "first 102", "late 101->102"), log,
            "a listener subscribed during a notification hears the next change only");
    }

    @Check(id = "cancel-is-per-registration")
    void cancelIsPerRegistration() {
        var ticker = new Ticker("ACME", 100);
        List<String> log = new ArrayList<>();
        PriceListener shared = logTo(log, "x");
        Runnable first = ticker.subscribe(shared);
        Runnable second = ticker.subscribe(shared);
        first.run();
        first.run();
        ticker.set(101);
        Expect.equal(List.of("x 100->101"), log,
            "the other registration of the same listener after cancelling one twice");
        second.run();
        ticker.set(102);
        Expect.equal(1, log.size(), "deliveries after cancelling both registrations");
    }

    @Check(id = "notify-outside-lock", kind = Kind.DESIGN)
    void notifyOutsideLock() {
        var hits = Source.type("Ticker").method("set").calls("onChange");
        Expect.isTrue(!hits.isEmpty(), "Ticker.set should still call onChange");
        Expect.none(hits.stream().filter(h -> h.insideSynchronized()).toList(),
            "Ticker.set calls listeners while holding a lock; a listener could deadlock it");
    }
}
