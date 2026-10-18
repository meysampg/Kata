import java.util.ArrayList;
import java.util.List;
import java.util.Map;

// [[contract
interface Prototype<T> {
    T copy();
}
// ]]

// [[unit
final class Unit implements Prototype<Unit> {
    private final String name;
    private final int hp;
    private final List<String> abilities;

    Unit(String name, int hp, List<String> abilities) {
        this.name = name;
        this.hp = hp;
        this.abilities = new ArrayList<>(abilities);
    }

    private Unit(Unit other) {
        this(other.name, other.hp, other.abilities);
    }

    public Unit copy() { return new Unit(this); }

    Unit learn(String ability) { abilities.add(ability); return this; }

    @Override public String toString() {
        return name + " hp=" + hp + " " + abilities;
    }
}
// ]]

class Main {
    public static void main(String[] args) {
        // [[registry
        Map<String, Unit> prototypes = Map.of(
            "orc", new Unit("orc", 30, List.of("slash")));
        // ]]
        // [[spawn
        Unit grunt = prototypes.get("orc").copy();
        Unit elite = prototypes.get("orc").copy().learn("rage");
        // ]]
        // [[check
        System.out.println(grunt);
        System.out.println(elite);
        System.out.println(prototypes.get("orc"));
        System.out.println(grunt != elite);
        // ]]
    }
}
