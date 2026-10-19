import java.util.ArrayList;
import java.util.List;

final class Patient {
    private final String id;
    private final String bedId;
    private final List<PatientDischarged> events = new ArrayList<>();
    private boolean discharged;

    Patient(String id, String bedId) {
        this.id = id;
        this.bedId = bedId;
    }

    void discharge() {
        if (discharged) throw new IllegalStateException("already discharged");
        discharged = true;
        events.add(new PatientDischarged(id, bedId));
    }

    List<PatientDischarged> pullEvents() {
        var out = List.copyOf(events);
        events.clear();
        return out;
    }

    boolean isDischarged() { return discharged; }
}
