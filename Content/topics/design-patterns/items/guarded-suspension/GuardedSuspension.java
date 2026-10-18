import java.util.ArrayList;
import java.util.List;

final class Mailbox<T> {
    private T item; // guarded by this

    // [[take
    synchronized T take() throws InterruptedException {
        while (item == null) {
            wait();
        }
        T value = item;
        item = null;
        notifyAll();
        return value;
    }
    // ]]

    // [[put
    synchronized void put(T value) throws InterruptedException {
        while (item != null) {
            wait();
        }
        item = value;
        notifyAll();
    }
    // ]]
}

class Main {
    public static void main(String[] args) throws InterruptedException {
        var box = new Mailbox<String>();
        var received = new ArrayList<String>();
        // [[consumer
        Thread consumer = new Thread(() -> {
            try {
                for (int i = 0; i < 3; i++) received.add(box.take());
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        });
        consumer.start();
        // ]]
        // [[producer
        for (String m : List.of("m1", "m2", "m3")) box.put(m);
        // ]]
        // [[join
        consumer.join();
        System.out.println(received);
        // ]]
    }
}
