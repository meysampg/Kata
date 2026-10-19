// One local transaction and the semantic undo that pairs with it.
record Step(String name, Runnable action, Runnable compensation) { }
