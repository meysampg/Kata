import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import kata.*;

/*
 * FeatureFlag's table is static, so it outlives a check. Every check starts with
 * FeatureFlag.reset() and builds the rows it needs. That is safe because the harness runs
 * checks one after another in a single JVM, never in parallel (see CONTENT_GUIDE "Tests").
 */
class ActiveRecordKataTest {
    @Check(id = "create-validates")
    void createValidates() {
        FeatureFlag.reset();
        FeatureFlag f = FeatureFlag.create("dark-mode", 25);
        Expect.equal("dark-mode", f.name(), "name");
        Expect.equal(25, f.percent(), "percent");
        Expect.isTrue(!f.enabled(), "a new flag starts disabled");
        Expect.raises(IllegalArgumentException.class, () -> FeatureFlag.create(" ", 0), "a blank name");
        Expect.raises(IllegalArgumentException.class, () -> FeatureFlag.create("x", 101), "percent 101");
        Expect.raises(IllegalArgumentException.class, () -> FeatureFlag.create("x", -1), "percent -1");
        Expect.raises(IllegalArgumentException.class, () -> f.rollout(150), "rollout(150)");
    }

    @Check(id = "new-is-not-stored")
    void newIsNotStored() {
        FeatureFlag.reset();
        FeatureFlag f = FeatureFlag.create("beta", 10);
        Expect.isTrue(!f.persisted(), "a new flag is not persisted");
        Expect.isTrue(FeatureFlag.find("beta").isEmpty(), "find before save");
        Expect.isTrue(f.save() == f, "save returns the same record");
        Expect.isTrue(f.persisted(), "persisted after save");
        Expect.equal(10, FeatureFlag.find("beta").orElseThrow().percent(), "stored percent");
    }

    @Check(id = "find-returns-fresh-copies")
    void findReturnsFreshCopies() {
        FeatureFlag.reset();
        FeatureFlag.create("beta", 10).save();
        FeatureFlag a = FeatureFlag.find("beta").orElseThrow();
        FeatureFlag b = FeatureFlag.find("beta").orElseThrow();
        Expect.isTrue(a != b, "find should build a new object each time");
        a.toggle();
        a.rollout(90);
        FeatureFlag c = FeatureFlag.find("beta").orElseThrow();
        Expect.isTrue(!c.enabled() && c.percent() == 10, "unsaved edits must not reach the table");
    }

    @Check(id = "update-after-edit")
    void updateAfterEdit() {
        FeatureFlag.reset();
        FeatureFlag.create("beta", 10).save();
        FeatureFlag f = FeatureFlag.find("beta").orElseThrow();
        Expect.isTrue(f.persisted(), "a found flag is persisted");
        f.toggle();
        f.rollout(60);
        f.save();
        FeatureFlag g = FeatureFlag.find("beta").orElseThrow();
        Expect.isTrue(g.enabled(), "enabled after toggle and save");
        Expect.equal(60, g.percent(), "percent after rollout and save");
        Expect.equal(1, FeatureFlag.all().size(), "update should not add a row");
    }

    @Check(id = "all-sorted-by-name")
    void allSortedByName() {
        FeatureFlag.reset();
        FeatureFlag.create("zeta", 1).save();
        FeatureFlag.create("alpha", 2).save();
        FeatureFlag.create("mid", 3).save();
        Expect.equal(List.of("alpha", "mid", "zeta"),
            FeatureFlag.all().stream().map(FeatureFlag::name).toList(), "names from all()");
    }

    @Check(id = "delete")
    void delete() {
        FeatureFlag.reset();
        FeatureFlag f = FeatureFlag.create("beta", 10).save();
        f.delete();
        Expect.isTrue(FeatureFlag.find("beta").isEmpty(), "find after delete");
        Expect.isTrue(!f.persisted(), "persisted after delete");
        FeatureFlag.create("never", 1).delete();
        f.save();
        Expect.isTrue(FeatureFlag.find("beta").isPresent(), "a deleted flag can be saved again");
    }

    @Check(id = "duplicate-insert-rejected")
    void duplicateInsertRejected() {
        FeatureFlag.reset();
        FeatureFlag.create("beta", 10).save();
        Expect.raises(IllegalStateException.class,
            () -> FeatureFlag.create("beta", 20).save(), "inserting a second flag named beta");
        Expect.equal(10, FeatureFlag.find("beta").orElseThrow().percent(), "the original row");
    }

    @Check(id = "record-persists-itself", kind = Kind.DESIGN)
    void recordPersistsItself() {
        Class<?> flag = Types.named("FeatureFlag");
        Method save = Types.method(flag, "save");
        Method delete = Types.method(flag, "delete");
        Expect.isTrue(!Modifier.isStatic(save.getModifiers()), "save should be an instance method");
        Expect.isTrue(!Modifier.isStatic(delete.getModifiers()), "delete should be an instance method");
        Method find = Types.staticMethod(flag, "find", String.class);
        Expect.equal(Optional.class, find.getReturnType(), "find's return type");
        Types.staticMethod(flag, "all");
    }

    @Check(id = "table-is-hidden", kind = Kind.DESIGN)
    void tableIsHidden() {
        Class<?> flag = Types.named("FeatureFlag");
        boolean found = false;
        for (Field f : flag.getDeclaredFields()) {
            if (Modifier.isStatic(f.getModifiers()) && Map.class.isAssignableFrom(f.getType())) {
                found = true;
                Expect.isTrue(Modifier.isPrivate(f.getModifiers()),
                    "FeatureFlag." + f.getName() + " holds the table and should be private");
                Expect.isTrue(!f.getGenericType().getTypeName().contains("FeatureFlag>"),
                    "FeatureFlag." + f.getName() + " keeps live FeatureFlag objects; the table"
                    + " should hold plain rows that find turns into fresh records");
            }
        }
        Expect.isTrue(found, "FeatureFlag should keep its table in a static Map field");
    }
}
