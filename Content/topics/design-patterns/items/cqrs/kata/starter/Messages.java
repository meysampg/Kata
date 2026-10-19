// The command and the fact it produces. Read-only.
record PlaceOrder(String orderId, String customer, int cents) { }

record OrderPlaced(String orderId, String customer, int cents) { }
