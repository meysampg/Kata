// What the other departments offer. Read-only.
interface Billing { void invoice(String patientId); }

interface Housekeeping { void cleanBed(String bedId); }

interface Pharmacy { void handOff(String patientId); }
