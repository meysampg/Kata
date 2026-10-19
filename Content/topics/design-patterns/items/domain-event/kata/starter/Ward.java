import java.util.HashMap;
import java.util.Map;

final class Ward {
    private final Map<String, Patient> patients = new HashMap<>();
    private final Billing billing;
    private final Housekeeping housekeeping;
    private final Pharmacy pharmacy;

    Ward(Billing billing, Housekeeping housekeeping, Pharmacy pharmacy) {
        this.billing = billing;
        this.housekeeping = housekeeping;
        this.pharmacy = pharmacy;
    }

    Patient admit(String id, String bedId) {
        var patient = new Patient(id, bedId, billing, housekeeping, pharmacy);
        patients.put(id, patient);
        return patient;
    }

    void discharge(String id) {
        Patient patient = patients.get(id);
        if (patient == null) {
            throw new IllegalArgumentException("unknown patient: " + id);
        }
        patient.discharge();
    }
}
