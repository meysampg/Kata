import java.lang.reflect.Field;
import java.util.ArrayList;
import java.util.List;
import kata.*;

class CommandKataTest {
    static final class Recording implements Command {
        final List<String> log;
        final String name;

        Recording(List<String> log, String name) { this.log = log; this.name = name; }

        public void execute() { log.add("do " + name); }
        public void undo() { log.add("undo " + name); }
    }

    @Check(id = "insert-and-undo")
    void insertAndUndo() {
        Doc doc = new Doc();
        History h = new History();
        h.run(new Insert(doc, 0, "Hello"));
        h.run(new Insert(doc, 5, " world"));
        Expect.equal("Hello world", doc.text(), "after two inserts");
        h.undo();
        Expect.equal("Hello", doc.text(), "after one undo");
        h.undo();
        Expect.equal("", doc.text(), "after two undos");
    }

    @Check(id = "delete-restores-what-it-removed")
    void deleteRestoresWhatItRemoved() {
        Doc doc = new Doc();
        History h = new History();
        h.run(new Insert(doc, 0, "Hello world"));
        h.run(new Delete(doc, 0, 6));
        Expect.equal("world", doc.text(), "after delete");
        h.undo();
        Expect.equal("Hello world", doc.text(), "undo of delete");
    }

    @Check(id = "redo-replays")
    void redoReplays() {
        Doc doc = new Doc();
        History h = new History();
        h.run(new Insert(doc, 0, "abc"));
        h.run(new Delete(doc, 1, 2));
        h.undo();
        h.undo();
        Expect.equal("", doc.text(), "after undoing everything");
        h.redo();
        Expect.equal("abc", doc.text(), "first redo");
        h.redo();
        Expect.equal("ac", doc.text(), "second redo");
        h.undo();
        Expect.equal("abc", doc.text(), "undo after redo restores the deleted text");
    }

    @Check(id = "delete-recaptures-on-redo")
    void deleteRecapturesOnRedo() {
        Doc doc = new Doc();
        History h = new History();
        h.run(new Insert(doc, 0, "one two"));
        Delete d = new Delete(doc, 0, 3);
        h.run(d);
        h.undo();
        h.undo();
        h.redo();
        h.redo();
        h.undo();
        Expect.equal("one two", doc.text(), "undo after a full undo/redo cycle");
    }

    @Check(id = "new-command-clears-redo")
    void newCommandClearsRedo() {
        Doc doc = new Doc();
        History h = new History();
        h.run(new Insert(doc, 0, "a"));
        h.run(new Insert(doc, 1, "b"));
        h.undo();
        Expect.isTrue(h.canRedo(), "after an undo there is something to redo");
        h.run(new Insert(doc, 1, "c"));
        Expect.isTrue(!h.canRedo(), "running a new command should drop the redo stack");
        h.redo();
        Expect.equal("ac", doc.text(), "redo with nothing to redo must change nothing");
    }

    @Check(id = "empty-history-is-safe")
    void emptyHistoryIsSafe() {
        History h = new History();
        Expect.isTrue(!h.canUndo() && !h.canRedo(), "a new History has nothing to undo or redo");
        h.undo();
        h.redo();
        Expect.isTrue(!h.canUndo() && !h.canRedo(), "undo/redo on an empty History must be no-ops");
    }

    @Check(id = "history-drives-any-command", kind = Kind.DESIGN)
    void historyDrivesAnyCommand() {
        List<String> log = new ArrayList<>();
        History h = new History();
        h.run(new Recording(log, "a"));
        h.run(new Recording(log, "b"));
        h.undo();
        h.redo();
        h.undo();
        h.undo();
        Expect.equal(List.of("do a", "do b", "undo b", "do b", "undo b", "undo a"), log,
            "History with Commands it has never seen");
    }

    @Check(id = "history-knows-no-edits", kind = Kind.DESIGN)
    void historyKnowsNoEdits() {
        var history = Source.type("History");
        for (String name : new String[] {"Doc", "Insert", "Delete"}) {
            Expect.none(history.mentions(name), "History mentions " + name + ": it should only know Command");
        }
        Expect.none(history.instanceofs(), "History inspects the concrete type of a Command");
        Expect.isTrue(Types.fieldsOfType(Types.named("History"), Doc.class).isEmpty(),
            "History should not hold a Doc");
    }

    @Check(id = "commands-hold-their-target", kind = Kind.DESIGN)
    void commandsHoldTheirTarget() {
        for (String name : new String[] {"Insert", "Delete"}) {
            Class<?> c = Types.named(name);
            Expect.isTrue(Command.class.isAssignableFrom(c), name + " should implement Command");
            Field f = Types.onlyFieldOfType(c, Doc.class);
            Expect.isTrue(java.lang.reflect.Modifier.isFinal(f.getModifiers()),
                name + "." + f.getName() + " should be final");
        }
    }
}
