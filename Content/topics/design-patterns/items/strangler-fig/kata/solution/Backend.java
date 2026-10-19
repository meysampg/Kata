interface Backend {
    String handle(String userId, String path);
}

final class LegacyBackend implements Backend {
    public String handle(String userId, String path) {
        return "legacy " + path;
    }
}

final class ModernBackend implements Backend {
    public String handle(String userId, String path) {
        return "modern " + path;
    }
}
