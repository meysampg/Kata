record OrderId(String value) { }

record Order(OrderId id, String customer, int totalCents) { }
