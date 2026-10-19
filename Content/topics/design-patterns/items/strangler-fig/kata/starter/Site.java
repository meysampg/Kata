// Pages are moving from the old system to the new one, path by path.
final class Site {
    String handle(String userId, String path) {
        int bucket = Math.floorMod(userId.hashCode(), 100);
        if (path.startsWith("/customers")) {
            return modern(path);                  // fully migrated
        }
        if (path.startsWith("/invoices")) {
            return bucket < 50 ? modern(path) : legacy(path);   // half
        }
        return legacy(path);
    }

    private String legacy(String path) {
        return "legacy " + path;
    }

    private String modern(String path) {
        return "modern " + path;
    }
}
