interface BlobStore {
    /** Stores the body and returns where it now lives. */
    String put(String key, String body);
}

interface EventBus {
    /** Publishes the message and returns the delivery receipt. */
    String publish(String topic, String message);
}

/** One consistent family of products. */
interface Infra {
    BlobStore blobs();
    EventBus events();
}
