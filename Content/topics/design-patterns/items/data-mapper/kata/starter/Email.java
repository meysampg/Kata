record Email(String value) {
    Email {
        if (!value.contains("@")) throw new IllegalArgumentException(value);
    }
}
