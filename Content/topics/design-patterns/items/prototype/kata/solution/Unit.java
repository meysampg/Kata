import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

interface Prototype<T> {
    T copy();
}

final class Unit implements Prototype<Unit> {
    private final String name;
    private final int hp;
    private final List<String> abilities;

    Unit(String name, int hp, List<String> abilities) {
        this.name = name;
        this.hp = hp;
        this.abilities = new ArrayList<>(abilities);
    }

    public Unit copy() { return new Unit(name, hp, abilities); }

    Unit learn(String ability) { abilities.add(ability); return this; }

    String name() { return name; }
    int hp() { return hp; }
    List<String> abilities() { return List.copyOf(abilities); }
}

final class Barracks {
    private final Map<String, Unit> prototypes = new HashMap<>();

    void register(String kind, Unit prototype) {
        prototypes.put(kind, prototype);
    }

    Unit spawn(String kind) {
        Unit prototype = prototypes.get(kind);
        if (prototype == null) {
            throw new IllegalArgumentException("unknown kind: " + kind);
        }
        return prototype.copy();
    }
}
