record Request(String path, String token) { }

record Response(int status, String body) { }

// A backend the gateway forwards to.
interface Service {
    Response handle(Request request);
}
