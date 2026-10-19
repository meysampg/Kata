// The aggregate calls every department itself.
final class Patient {
    private final String id;
    private final String bedId;
    private final Billing billing;
    private final Housekeeping housekeeping;
    private final Pharmacy pharmacy;
    private boolean discharged;

    Patient(String id, String bedId, Billing billing,
            Housekeeping housekeeping, Pharmacy pharmacy) {
        this.id = id;
        this.bedId = bedId;
        this.billing = billing;
        this.housekeeping = housekeeping;
        this.pharmacy = pharmacy;
    }

    void discharge() {
        if (discharged) throw new IllegalStateException("already discharged");
        discharged = true;
        billing.invoice(id);
        housekeeping.cleanBed(bedId);
        pharmacy.handOff(id);
    }

    boolean isDischarged() { return discharged; }
}
