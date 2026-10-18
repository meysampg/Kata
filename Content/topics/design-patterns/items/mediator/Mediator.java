import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

// [[mediator
interface Room {
    void join(Member m);
    void send(Member from, String text);
}
// ]]

// [[colleague
final class Member {
    private final String name;
    private final List<String> inbox = new ArrayList<>();
    private Room room;

    Member(String name) { this.name = name; }

    String name() { return name; }
    List<String> inbox() { return inbox; }

    void enter(Room room) { this.room = room; room.join(this); }
    void say(String text) { room.send(this, text); }
    void receive(String from, String text) { inbox.add(from + ": " + text); }
}
// ]]

// [[concrete
final class ModeratedRoom implements Room {
    private final List<Member> members = new ArrayList<>();
    private final Set<String> muted = new HashSet<>();

    void mute(String name) { muted.add(name); }

    public void join(Member m) { members.add(m); }

    public void send(Member from, String text) {
        if (muted.contains(from.name())) return;
        for (Member m : members) {
            if (m != from) m.receive(from.name(), text);
        }
    }
}
// ]]

class Main {
    public static void main(String[] args) {
        // [[client
        var room = new ModeratedRoom();
        var ana = new Member("ana");
        var bo = new Member("bo");
        var cy = new Member("cy");
        for (Member m : List.of(ana, bo, cy)) m.enter(room);
        // ]]
        // [[traffic
        ana.say("hi");
        room.mute("bo");
        bo.say("spam");
        cy.say("hello");
        // ]]
        System.out.println("ana=" + ana.inbox());
        System.out.println("bo=" + bo.inbox());
        System.out.println("cy=" + cy.inbox());
    }
}
