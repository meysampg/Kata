final class Site {
    private final Backend entry =
        new StranglerFacade(new LegacyBackend(), new ModernBackend())
            .migrate("/customers", 100)
            .migrate("/invoices", 50);

    String handle(String userId, String path) {
        return entry.handle(userId, path);
    }
}
