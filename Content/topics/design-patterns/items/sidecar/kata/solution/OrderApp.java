final class OrderApp implements Handler {
    @Override
    public Response handle(Request request) {
        String id = request.path().substring("/orders/".length());
        return new Response(200, "order:" + id);
    }
}
