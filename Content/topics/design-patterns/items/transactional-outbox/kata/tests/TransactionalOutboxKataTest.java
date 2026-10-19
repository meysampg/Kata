import java.io.IOException;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.List;
import kata.*;

class TransactionalOutboxKataTest {
    static final class Recorder implements Broker {
        final List<String> seen = new ArrayList<>();
        int failFrom = -1;     // calls with index >= failFrom fail while 'down'
        boolean down;
        int calls;

        public void publish(Message m) throws IOException {
            calls++;
            if (down && calls >= failFrom) throw new IOException("broker down");
            seen.add(m.type() + ":" + m.payload());
        }
    }

    @Check(id = "order-is-saved-and-announced")
    void savedAndAnnounced() {
        Db db = new Db();
        Recorder broker = new Recorder();
        Shop shop = new Shop(db, broker);
        Expect.isTrue(shop.place("o-1"), "place(o-1) should succeed");
        shop.deliver();
        Expect.equal(List.of("o-1"), db.orders, "saved orders");
        Expect.equal(List.of("OrderPlaced:o-1"), broker.seen, "messages the broker received");
    }

    @Check(id = "rollback-announces-nothing")
    void rollbackAnnouncesNothing() {
        Db db = new Db();
        Recorder broker = new Recorder();
        Shop shop = new Shop(db, broker);
        shop.place("o-1");
        Expect.isTrue(!shop.place("o-1"), "a duplicate order is rejected");
        shop.deliver();
        Expect.equal(List.of("OrderPlaced:o-1"), broker.seen, "messages the broker received");
        Expect.equal(List.of("o-1"), db.orders, "saved orders");
    }

    @Check(id = "messages-keep-order")
    void messagesKeepOrder() {
        Db db = new Db();
        Recorder broker = new Recorder();
        Shop shop = new Shop(db, broker);
        shop.place("a");
        shop.place("b");
        shop.place("c");
        shop.deliver();
        Expect.equal(List.of("OrderPlaced:a", "OrderPlaced:b", "OrderPlaced:c"), broker.seen, "delivery order");
    }

    @Check(id = "delivered-once")
    void deliveredOnce() {
        Db db = new Db();
        Recorder broker = new Recorder();
        Shop shop = new Shop(db, broker);
        shop.place("a");
        shop.deliver();
        Expect.equal(0, shop.deliver(), "messages delivered by a second call");
        Expect.equal(1, broker.seen.size(), "messages the broker received");
    }

    @Check(id = "service-does-not-publish", kind = Kind.DESIGN)
    void serviceDoesNotPublish() {
        var svc = Source.type("OrderService");
        Expect.none(svc.mentions("Broker"), "OrderService still talks to the Broker");
        Expect.none(svc.calls("publish"), "OrderService still publishes directly");
        Expect.isTrue(Types.fieldsOfType(Types.named("OrderService"), Broker.class).isEmpty(),
            "OrderService still holds a Broker");
    }

    @Check(id = "order-and-row-commit-together", kind = Kind.DESIGN)
    void commitTogether() throws Throwable {
        Db db = new Db();
        Class<?> cls = Types.named("OrderService");
        Object svc = Types.create(Types.constructor(cls, Db.class), db);
        Method place = Types.method(cls, "place", String.class);
        Expect.equal(true, Types.call(place, svc, "o-1"), "place(o-1)");
        Expect.equal(1, db.orders.size(), "orders saved");
        Expect.equal(1, db.outbox.size(), "outbox rows written in the same transaction");
        Expect.equal("OrderPlaced", db.outbox.get(0).type(), "the row's type");
        Expect.equal("o-1", db.outbox.get(0).payload(), "the row's payload");
        Expect.equal(false, Types.call(place, svc, "o-1"), "a duplicate place(o-1)");
        Expect.equal(1, db.outbox.size(), "A rolled-back order must leave no outbox row");
    }

    @Check(id = "relay-retries-until-acked", kind = Kind.DESIGN)
    void relayRetries() throws Throwable {
        Db db = new Db();
        Recorder broker = new Recorder();
        Class<?> svcType = Types.named("OrderService");
        Object svc = Types.create(Types.constructor(svcType, Db.class), db);
        Types.call(Types.method(svcType, "place", String.class), svc, "o-1");
        Class<?> relayType = Types.named("Relay");
        Object relay = Types.create(Types.constructor(relayType, Db.class, Broker.class), db, broker);
        Method pump = Types.method(relayType, "pump");
        broker.down = true;
        broker.failFrom = 1;
        Expect.equal(0, Types.call(pump, relay), "rows sent while the broker is down");
        Expect.equal(1, db.pending().size(), "A row that was not acknowledged must stay pending");
        broker.down = false;
        Expect.equal(1, Types.call(pump, relay), "rows sent once the broker is back");
        Expect.equal(List.of("OrderPlaced:o-1"), broker.seen, "messages received");
        Expect.equal(0, Types.call(pump, relay), "rows sent by a third pump (no duplicates)");
    }

    @Check(id = "relay-stops-at-first-failure", kind = Kind.DESIGN)
    void relayKeepsOrder() throws Throwable {
        Db db = new Db();
        Recorder broker = new Recorder();
        Class<?> svcType = Types.named("OrderService");
        Object svc = Types.create(Types.constructor(svcType, Db.class), db);
        Method place = Types.method(svcType, "place", String.class);
        for (String id : List.of("a", "b", "c")) Types.call(place, svc, id);
        Class<?> relayType = Types.named("Relay");
        Object relay = Types.create(Types.constructor(relayType, Db.class, Broker.class), db, broker);
        Method pump = Types.method(relayType, "pump");
        broker.down = true;
        broker.failFrom = 2;      // the second publish fails
        Expect.equal(1, Types.call(pump, relay), "rows sent before the failure");
        Expect.equal(List.of("OrderPlaced:a"), broker.seen, "messages received");
        broker.down = false;
        Expect.equal(2, Types.call(pump, relay), "rows sent by the next pump");
        Expect.equal(List.of("OrderPlaced:a", "OrderPlaced:b", "OrderPlaced:c"), broker.seen,
            "Order must be preserved across a failure");
    }
}
