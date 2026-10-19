import java.util.concurrent.atomic.AtomicInteger;

// Expensive to build: pretend it reads and decodes an image.
final class Texture {
    private static final AtomicInteger LOADED = new AtomicInteger();

    private final String species;
    private final String color;

    Texture(String species, String color) {
        LOADED.incrementAndGet();
        this.species = species;
        this.color = color;
    }

    String fingerprint() {
        return Math.abs((species + color).hashCode() % 1000) + "";
    }

    // How many Textures exist so far, across the whole program.
    static int loaded() { return LOADED.get(); }
}
