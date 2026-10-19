import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.util.ArrayList;
import java.util.List;
import kata.*;

class EventSourcingKataTest {
    static final List<StockEvent> HISTORY =
        List.of(new Received(10), new Picked(3), new Adjusted(-2));

    @Check(id = "replay-rebuilds-state")
    void replayRebuildsState() {
        StockItem item = StockItem.replay(HISTORY);
        Expect.equal(5, item.onHand(), "on hand after replay");
        Expect.equal(3, item.version(), "version after replay");
        Expect.equal(List.of(), item.pendingEvents(), "replayed events are not pending");
        Expect.equal(0, StockItem.replay(List.of()).version(), "version of an empty history");
    }

    @Check(id = "replay-any-prefix")
    void replayAnyPrefix() {
        StockItem then = StockItem.replay(HISTORY.subList(0, 2));
        Expect.equal(7, then.onHand(), "on hand at version 2");
        Expect.equal(2, then.version(), "version at version 2");
    }

    @Check(id = "commands-record-events")
    void commandsRecordEvents() {
        StockItem item = StockItem.replay(List.of());
        item.receive(8);
        item.pick(3);
        item.adjust(1);
        Expect.equal(List.of(new Received(8), new Picked(3), new Adjusted(1)),
            item.pendingEvents(), "pending events");
        Expect.equal(6, item.onHand(), "on hand");
        Expect.equal(3, item.version(), "version");
    }

    @Check(id = "rules-reject-without-events")
    void rulesRejectWithoutEvents() {
        StockItem item = StockItem.replay(List.of(new Received(2)));
        Expect.raises(IllegalStateException.class, () -> item.pick(3), "picking more than on hand");
        Expect.raises(IllegalStateException.class, () -> item.adjust(-3), "adjusting below zero");
        Expect.raises(IllegalArgumentException.class, () -> item.receive(0), "receiving 0 units");
        Expect.raises(IllegalArgumentException.class, () -> item.pick(-1), "picking -1 units");
        Expect.equal(List.of(), item.pendingEvents(), "events after rejected commands");
        Expect.equal(1, item.version(), "version after rejected commands");
    }

    @Check(id = "save-appends-pending")
    void saveAppendsPending() {
        var store = new EventStore();
        StockItem item = StockItem.replay(store.load("sku-42"));
        item.receive(10);
        item.pick(4);
        item.saveTo(store, "sku-42");
        Expect.equal(List.of(new Received(10), new Picked(4)), store.load("sku-42"), "stored events");
        Expect.equal(List.of(), item.pendingEvents(), "pending after save");
        item.saveTo(store, "sku-42");
        item.adjust(-1);
        item.saveTo(store, "sku-42");
        Expect.equal(3, store.load("sku-42").size(), "events after a no-op save and one more");
        Expect.equal(List.of(), store.load("other"), "an unknown stream");
    }

    @Check(id = "stale-save-conflicts")
    void staleSaveConflicts() {
        var store = new EventStore();
        StockItem seed = StockItem.replay(List.of());
        seed.receive(10);
        seed.saveTo(store, "sku-42");

        StockItem mine = StockItem.replay(store.load("sku-42"));
        StockItem rival = StockItem.replay(store.load("sku-42"));
        rival.pick(1);
        rival.saveTo(store, "sku-42");
        mine.pick(2);
        Expect.raises(VersionConflict.class, () -> mine.saveTo(store, "sku-42"),
            "saving on top of a stream that moved on");
        Expect.equal(List.of(new Received(10), new Picked(1)), store.load("sku-42"),
            "the stream after a rejected save");
    }

    @Check(id = "history-is-protected")
    void historyIsProtected() {
        var store = new EventStore();
        var batch = new ArrayList<StockEvent>(List.of(new Received(1)));
        store.append("s", 0, batch);
        batch.add(new Picked(1));
        Expect.equal(1, store.load("s").size(), "a caller's list must not stay linked to the stream");
        Expect.raises(UnsupportedOperationException.class,
            () -> store.load("s").add(new Picked(1)), "adding to a loaded history");
    }

    @Check(id = "events-are-immutable-records", kind = Kind.DESIGN)
    void eventsAreImmutableRecords() {
        for (String name : List.of("Received", "Picked", "Adjusted")) {
            Expect.isTrue(Types.named(name).isRecord(), name + " should be a record");
        }
    }

    @Check(id = "store-keeps-events-not-state", kind = Kind.DESIGN)
    void storeKeepsEventsNotState() {
        Class<?> store = Types.named("EventStore");
        Expect.isTrue(Types.fieldsOfType(store, Types.named("StockItem")).isEmpty(),
            "EventStore holds StockItem state; it should hold events only");
        Expect.none(Source.type("EventStore").mentions("onHand"), "EventStore knows about stock levels");
    }

    @Check(id = "rebuild-is-a-static-replay", kind = Kind.DESIGN)
    void rebuildIsAStaticReplay() {
        Method replay = Types.staticMethod(Types.named("StockItem"), "replay", List.class);
        Expect.equal(Types.named("StockItem"), replay.getReturnType(), "replay's return type");
        for (Method m : Types.named("StockItem").getDeclaredMethods()) {
            boolean setterLike = !Modifier.isPrivate(m.getModifiers()) && m.getName().startsWith("set");
            Expect.isTrue(!setterLike, "StockItem." + m.getName() + " lets callers set state directly");
        }
    }
}
