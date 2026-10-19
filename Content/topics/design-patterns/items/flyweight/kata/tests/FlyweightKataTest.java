import java.lang.reflect.Method;
import kata.*;

class FlyweightKataTest {
    static final String[] KINDS = {"oak", "pine", "birch"};

    static Forest plant(String prefix, int trees) {
        Forest forest = new Forest();
        for (int i = 0; i < trees; i++) {
            String kind = prefix + KINDS[i % 3];
            forest.plant(kind, i % 3 == 0 ? "green" : "dark", i, i * 2);
        }
        return forest;
    }

    @Check(id = "draw-text")
    void drawText() {
        Forest forest = new Forest();
        forest.plant("oak", "green", 10, 5);
        forest.plant("pine", "dark", 0, 1);
        Expect.equal(2, forest.size(), "trees planted");
        Expect.equal("oak@10,5 green #" + new Texture("oak", "green").fingerprint(),
            forest.draw(0), "drawing the first tree");
        Expect.equal("pine@0,1 dark #" + new Texture("pine", "dark").fingerprint(),
            forest.draw(1), "drawing the second tree");
    }

    @Check(id = "many-trees-keep-their-positions")
    void manyTreesKeepTheirPositions() {
        Forest forest = plant("pos-", 300);
        Expect.equal(300, forest.size(), "trees planted");
        Expect.isTrue(forest.draw(297).startsWith("pos-oak@297,594 green"),
            "tree 297 should still stand at 297,594 but draws " + forest.draw(297));
        Expect.isTrue(forest.draw(7).startsWith("pos-pine@7,14 dark"),
            "tree 7 should still stand at 7,14 but draws " + forest.draw(7));
    }

    @Check(id = "textures-load-once-per-kind", kind = Kind.DESIGN)
    void texturesLoadOncePerKind() {
        int before = Texture.loaded();
        plant("count-", 1000);
        int made = Texture.loaded() - before;
        Expect.isTrue(made <= 3,
            "1000 trees of 3 kinds built " + made + " Textures; expected at most 3");
    }

    @Check(id = "two-forests-share", kind = Kind.DESIGN)
    void twoForestsShare() {
        plant("shared-", 30);
        int before = Texture.loaded();
        plant("shared-", 30);
        Expect.equal(0, Texture.loaded() - before,
            "a second forest of known kinds should build no new Textures");
    }

    @Check(id = "factory-returns-the-same-instance", kind = Kind.DESIGN)
    void factoryReturnsTheSameInstance() throws Throwable {
        Method of = Types.staticMethod(Types.named("TreeTypes"), "of", String.class, String.class);
        Object a = Types.call(of, null, "elm", "red");
        Object b = Types.call(of, null, "elm", "red");
        Object c = Types.call(of, null, "elm", "gold");
        Expect.isTrue(a == b, "TreeTypes.of(\"elm\", \"red\") twice should be one shared object");
        Expect.isTrue(a != c, "different colours should be different TreeTypes");
        Expect.equal(Types.named("TreeType"), a.getClass(), "what TreeTypes.of returns");
    }

    @Check(id = "tree-and-forest-do-not-build-types", kind = Kind.DESIGN)
    void treeAndForestDoNotBuildTypes() {
        for (String owner : new String[] {"Tree", "Forest"}) {
            var shape = Source.type(owner);
            Expect.none(shape.news("Texture"), owner + " builds a Texture itself");
            Expect.none(shape.news("TreeType"), owner + " builds a TreeType itself");
        }
    }

    @Check(id = "tree-keeps-no-appearance", kind = Kind.DESIGN)
    void treeKeepsNoAppearance() {
        Class<?> tree = Types.named("Tree");
        Expect.isTrue(Types.fieldsOfType(tree, Texture.class).isEmpty(),
            "Tree should not hold its own Texture");
        Expect.isTrue(Types.fieldsOfType(tree, String.class).isEmpty(),
            "Tree should not copy the species or colour strings");
    }
}
