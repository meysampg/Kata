import java.lang.reflect.Constructor;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.util.List;
import kata.*;

class MementoKataTest {
    static Editor editorWith(String text) {
        var e = new Editor();
        e.type(text);
        return e;
    }

    @Check(id = "restores-text-and-cursor")
    void restoresTextAndCursor() {
        var e = editorWith("Hello");
        e.moveTo(2);
        var saved = e.save();
        e.type("XY");
        e.delete(1);
        e.moveTo(0);
        e.restore(saved);
        Expect.equal("Hello", e.text(), "the text");
        Expect.equal(2, e.cursor(), "the cursor");
    }

    @Check(id = "snapshot-is-a-copy")
    void snapshotIsACopy() {
        var e = editorWith("ab");
        var saved = e.save();
        e.type("cd");
        e.restore(saved);
        Expect.equal("ab", e.text(), "after the first restore");
        e.type("Z");
        e.restore(saved);
        Expect.equal("ab", e.text(), "restoring the same snapshot again");
        Expect.equal(2, e.cursor(), "the cursor after restoring again");
    }

    @Check(id = "snapshots-are-independent")
    void snapshotsAreIndependent() {
        var e = editorWith("a");
        var first = e.save();
        e.type("b");
        var second = e.save();
        e.restore(first);
        Expect.equal("a", e.text(), "the first snapshot");
        e.restore(second);
        Expect.equal("ab", e.text(), "the second snapshot");
    }

    @Check(id = "undo-steps-back")
    void undoStepsBack() {
        var e = new Editor();
        var history = new History(e);
        history.checkpoint();
        e.type("A");
        history.checkpoint();
        e.type("B");
        Expect.isTrue(history.undo(), "first undo");
        Expect.equal("A", e.text(), "after the first undo");
        Expect.isTrue(history.undo(), "second undo");
        Expect.equal("", e.text(), "after the second undo");
    }

    @Check(id = "undo-with-nothing-saved")
    void undoWithNothingSaved() {
        var e = editorWith("keep");
        var history = new History(e);
        Expect.isTrue(!history.undo(), "undo without a checkpoint");
        Expect.equal("keep", e.text(), "the text is left alone");
    }

    @Check(id = "checkpoint-after-undo")
    void checkpointAfterUndo() {
        var e = new Editor();
        var history = new History(e);
        history.checkpoint();
        e.type("a");
        history.undo();
        e.type("b");
        history.checkpoint();
        e.type("c");
        history.undo();
        Expect.equal("b", e.text(), "undo after a new checkpoint");
        Expect.equal(1, e.cursor(), "the cursor");
    }

    @Check(id = "memento-is-its-own-type", kind = Kind.DESIGN)
    void mementoIsItsOwnType() {
        Class<?> type = Types.method(Types.named("Editor"), "save").getReturnType();
        Expect.isTrue(type.getClassLoader() == Editor.class.getClassLoader()
                && type != Editor.class,
            "save() should return a dedicated memento type, not " + type.getSimpleName());
    }

    @Check(id = "memento-exposes-nothing", kind = Kind.DESIGN)
    void mementoExposesNothing() {
        Class<?> declared = Types.method(Types.named("Editor"), "save").getReturnType();
        Expect.isTrue(declared.getClassLoader() == Editor.class.getClassLoader()
                && declared != Editor.class,
            "save() should return a dedicated memento type, not " + declared.getSimpleName());
        assertOpaque(declared);
        assertOpaque(editorWith("x").save().getClass());
    }

    /** A type the caretaker can name must offer no way to read or forge the state. */
    static void assertOpaque(Class<?> type) {
        if (type.isMemberClass() && Modifier.isPrivate(type.getModifiers())) {
            return;   // only its enclosing class can touch it
        }
        String name = type.getSimpleName();
        for (Method m : type.getDeclaredMethods()) {
            String n = m.getName();
            if (m.isSynthetic() || Modifier.isStatic(m.getModifiers()) && n.startsWith("lambda$")
                    || n.equals("equals") || n.equals("hashCode") || n.equals("toString")) {
                continue;
            }
            Expect.isTrue(Modifier.isPrivate(m.getModifiers()),
                name + "." + n + "() lets the caretaker read the state; make it private"
                    + " or hide the memento's class inside Editor");
        }
        for (Field f : type.getDeclaredFields()) {
            if (f.isSynthetic() || Modifier.isStatic(f.getModifiers())) {
                continue;
            }
            Expect.isTrue(Modifier.isPrivate(f.getModifiers()),
                name + "." + f.getName() + " can be read from outside Editor; make it private");
        }
        for (Constructor<?> c : type.getDeclaredConstructors()) {
            Expect.isTrue(Modifier.isPrivate(c.getModifiers()),
                "anyone can forge a " + name + " through its constructor; make it private");
        }
    }

    @Check(id = "memento-is-immutable", kind = Kind.DESIGN)
    void mementoIsImmutable() {
        Object saved = editorWith("x").save();
        for (var f : saved.getClass().getDeclaredFields()) {
            if (f.isSynthetic() || Modifier.isStatic(f.getModifiers())) {
                continue;
            }
            Expect.isTrue(Modifier.isFinal(f.getModifiers()),
                saved.getClass().getSimpleName() + "." + f.getName() + " should be final");
        }
    }

    @Check(id = "history-never-reads-state", kind = Kind.DESIGN)
    void historyNeverReadsState() {
        var history = Source.type("History");
        Expect.none(history.calls("text"), "History reads the editor's text");
        Expect.none(history.calls("cursor"), "History reads the editor's cursor");
        Expect.none(history.calls("type"), "History edits the editor");
        Expect.none(history.calls("delete"), "History edits the editor");
        Expect.none(history.calls("moveTo"), "History edits the editor");
    }
}
