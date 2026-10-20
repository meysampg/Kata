import java.lang.reflect.Constructor;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.List;
import java.util.function.Consumer;
import kata.*;

class DomainEventKataTest {
    final List<String> log = new ArrayList<>();

    Ward ward() {
        return new Ward(
            id -> log.add("bill " + id),
            bed -> log.add("clean " + bed),
            id -> log.add("pharmacy " + id));
    }

    @Check(id = "discharge-reaches-everyone")
    void dischargeReachesEveryone() {
        Ward ward = ward();
        ward.admit("p-1", "bed-7");
        ward.discharge("p-1");
        Expect.equal(List.of("bill p-1", "clean bed-7", "pharmacy p-1"), log,
            "reactions to a discharge, in order");
        Expect.isTrue(ward.admit("p-2", "bed-8") != null, "admit still returns the patient");
    }

    @Check(id = "double-discharge-rejected")
    void doubleDischargeRejected() {
        Ward ward = ward();
        ward.admit("p-1", "bed-7");
        ward.discharge("p-1");
        Expect.raises(IllegalStateException.class, () -> ward.discharge("p-1"),
            "discharging the same patient twice");
        Expect.equal(3, log.size(), "reactions after a rejected second discharge");
    }

    @Check(id = "unknown-patient")
    void unknownPatient() {
        Expect.raises(IllegalArgumentException.class, () -> ward().discharge("ghost"),
            "discharging an unknown patient");
        Expect.equal(List.of(), log, "reactions to an unknown patient");
    }

    @Check(id = "patients-are-independent")
    void patientsAreIndependent() {
        Ward ward = ward();
        Patient a = ward.admit("p-1", "bed-1");
        Patient b = ward.admit("p-2", "bed-2");
        ward.discharge("p-2");
        Expect.equal(List.of("bill p-2", "clean bed-2", "pharmacy p-2"), log, "reactions");
        Expect.isTrue(b.isDischarged() && !a.isDischarged(), "only p-2 is discharged");
    }

    @Check(id = "event-names-what-happened", kind = Kind.DESIGN)
    void eventNamesWhatHappened() throws Throwable {
        Class<?> event = Types.named("PatientDischarged");
        Expect.isTrue(event.isRecord(), "PatientDischarged should be a record");
        Object e = Types.create(Types.constructor(event, String.class, String.class), "p-1", "bed-7");
        Expect.equal("p-1", Types.call(Types.method(event, "patientId"), e), "patientId()");
        Expect.equal("bed-7", Types.call(Types.method(event, "bedId"), e), "bedId()");
    }

    @Check(id = "patient-records-the-event", kind = Kind.DESIGN)
    void patientRecordsTheEvent() throws Throwable {
        Class<?> event = Types.named("PatientDischarged");
        Patient patient = ward().admit("p-1", "bed-7");
        Method pull = Types.method(Patient.class, "pullEvents");
        Expect.equal(0, ((List<?>) Types.call(pull, patient)).size(), "events before discharge");
        patient.discharge();
        List<?> events = (List<?>) Types.call(pull, patient);
        Expect.equal(1, events.size(), "events after discharge");
        Expect.isTrue(event.isInstance(events.get(0)), "the event should be a PatientDischarged");
        Expect.equal(0, ((List<?>) Types.call(pull, patient)).size(), "events after pulling them");
        Expect.equal(List.of(), log, "Patient.discharge should not call a department");
    }

    @Check(id = "patient-knows-no-department", kind = Kind.DESIGN)
    void patientKnowsNoDepartment() {
        Class<?> patient = Types.named("Patient");
        for (String port : List.of("Billing", "Housekeeping", "Pharmacy")) {
            Class<?> p = Types.named(port);
            Expect.isTrue(Types.fieldsOfType(patient, p).isEmpty(), "Patient still holds a " + port);
            for (Constructor<?> c : patient.getDeclaredConstructors()) {
                Expect.isTrue(!List.of(c.getParameterTypes()).contains(p),
                    "A Patient constructor still takes a " + port);
            }
            Expect.none(Source.type("Patient").mentions(port), "Patient still mentions " + port);
        }
    }

    @Check(id = "bus-routes-by-type", kind = Kind.DESIGN)
    void busRoutesByType() throws Throwable {
        Class<?> bus = Types.named("EventBus");
        Class<?> event = Types.named("PatientDischarged");
        Object b = Types.create(Types.constructor(bus));
        List<Object> seen = new ArrayList<>();
        Consumer<Object> handler = seen::add;
        Types.call(Types.method(bus, "on", Class.class, Consumer.class), b, event, handler);
        Object e = Types.create(Types.constructor(event, String.class, String.class), "p", "b");
        Types.call(Types.method(bus, "publish", List.class), b, List.of("noise", e));
        Expect.equal(List.of(e), seen, "events delivered to a handler for PatientDischarged");
    }

    @Check(id = "ward-publishes-what-patient-recorded", kind = Kind.DESIGN)
    void wardPublishesWhatPatientRecorded() {
        var discharge = Source.type("Ward").method("discharge");
        for (String call : List.of("invoice", "cleanBed", "handOff")) {
            Expect.none(discharge.calls(call), "Ward.discharge still calls " + call
                + " directly; let a handler subscribed on the EventBus react to the event");
        }
        Expect.none(discharge.news("PatientDischarged"),
            "Ward.discharge makes up the event itself; publish what the patient recorded");
        Expect.isTrue(!discharge.calls("pullEvents").isEmpty() && !discharge.calls("publish").isEmpty(),
            "Ward.discharge should publish the events it pulls from the patient");
    }
}
