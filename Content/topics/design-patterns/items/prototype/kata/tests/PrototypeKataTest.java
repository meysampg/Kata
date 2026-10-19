import java.lang.reflect.Field;
import java.lang.reflect.Modifier;
import java.util.ArrayList;
import java.util.List;
import kata.*;

class PrototypeKataTest {
    static Unit orc() {
        return new Unit("orc", 30, new ArrayList<>(List.of("slash")));
    }

    @Check(id = "copy-has-the-same-state")
    void copyHasTheSameState() {
        Unit original = orc();
        Unit copy = original.copy();
        Expect.isTrue(copy != original, "copy() should return a new object");
        Expect.equal("orc", copy.name(), "copied name");
        Expect.equal(30, copy.hp(), "copied hp");
        Expect.equal(List.of("slash"), copy.abilities(), "copied abilities");
    }

    @Check(id = "learning-on-the-copy-leaves-the-original")
    void learningOnTheCopyLeavesTheOriginal() {
        Unit original = orc();
        original.copy().learn("rage");
        Expect.equal(List.of("slash"), original.abilities(),
            "the prototype's abilities after its copy learned one");
    }

    @Check(id = "learning-on-the-original-leaves-the-copy")
    void learningOnTheOriginalLeavesTheCopy() {
        Unit original = orc();
        Unit copy = original.copy();
        original.learn("rage");
        Expect.equal(List.of("slash"), copy.abilities(),
            "the copy's abilities after the original learned one");
    }

    @Check(id = "constructor-does-not-keep-the-callers-list")
    void constructorDoesNotKeepTheCallersList() {
        List<String> given = new ArrayList<>(List.of("slash"));
        Unit unit = new Unit("orc", 30, given);
        given.add("rage");
        Expect.equal(List.of("slash"), unit.abilities(),
            "a unit's abilities after the list it was built from changed");
    }

    @Check(id = "barracks-spawns-independent-units")
    void barracksSpawnsIndependentUnits() {
        Barracks barracks = new Barracks();
        Unit prototype = orc();
        barracks.register("orc", prototype);
        Unit grunt = barracks.spawn("orc");
        Unit elite = barracks.spawn("orc").learn("rage");
        Expect.equal(List.of("slash"), grunt.abilities(), "grunt");
        Expect.equal(List.of("slash", "rage"), elite.abilities(), "elite");
        Expect.equal(List.of("slash"), prototype.abilities(), "the registered prototype");
    }

    @Check(id = "unknown-kind")
    void unknownKind() {
        Expect.raises(IllegalArgumentException.class,
            () -> new Barracks().spawn("dragon"), "an unknown kind");
    }

    @Check(id = "copy-returns-unit", kind = Kind.DESIGN)
    void copyReturnsUnit() {
        Class<?> unit = Types.named("Unit");
        Class<?> contract = Types.named("Prototype");
        Expect.isTrue(contract.isAssignableFrom(unit), "Unit should implement Prototype");
        Expect.equal(unit, Types.method(unit, "copy").getReturnType(),
            "the return type of Unit.copy() (callers should not need a cast)");
    }

    @Check(id = "mutable-fields-are-not-shared", kind = Kind.DESIGN)
    void mutableFieldsAreNotShared() throws Exception {
        Unit original = orc();
        Unit copy = original.copy();
        for (Field f : Unit.class.getDeclaredFields()) {
            if (Modifier.isStatic(f.getModifiers()) || f.getType().isPrimitive()) continue;
            f.setAccessible(true);
            Object a = f.get(original);
            Object b = f.get(copy);
            boolean immutable = a instanceof String || a instanceof Number
                || a != null && a.getClass().getName().startsWith("java.util.ImmutableCollections");
            Expect.isTrue(immutable || a != b,
                "Unit." + f.getName() + " is the same mutable object in the original and its copy");
        }
    }
}
