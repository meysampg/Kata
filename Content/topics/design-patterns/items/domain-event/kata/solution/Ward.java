import java.util.HashMap;
import java.util.Map;

final class Ward {
    private final Map<String, Patient> patients = new HashMap<>();
    private final EventBus bus = new EventBus();

    Ward(Billing billing, Housekeeping housekeeping, Pharmacy pharmacy) {
        bus.on(PatientDischarged.class, e -> billing.invoice(e.patientId()));
        bus.on(PatientDischarged.class, e -> housekeeping.cleanBed(e.bedId()));
        bus.on(PatientDischarged.class, e -> pharmacy.handOff(e.patientId()));
    }

    Patient admit(String id, String bedId) {
        var patient = new Patient(id, bedId);
        patients.put(id, patient);
        return patient;
    }

    void discharge(String id) {
        Patient patient = patients.get(id);
        if (patient == null) {
            throw new IllegalArgumentException("unknown patient: " + id);
        }
        patient.discharge();
        bus.publish(patient.pullEvents());
    }
}
