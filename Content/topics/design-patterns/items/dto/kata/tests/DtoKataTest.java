import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.lang.reflect.ParameterizedType;
import java.util.List;
import java.util.Map;
import java.util.Set;
import kata.*;

class DtoKataTest {
    static Map<String, Object> wire(Object body) {
        return Json.fields(body);
    }

    @Check(id = "show-hides-secrets")
    void showHidesSecrets() {
        var body = wire(new UserApi().show(7));
        Expect.isTrue(!body.containsKey("passwordHash"), "show(7) sends the password hash");
        Expect.isTrue(!body.containsKey("email") && !body.containsKey("roles"),
            "show(7) sends private details: " + body.keySet());
    }

    @Check(id = "show-has-the-summary")
    void showHasTheSummary() {
        var body = wire(new UserApi().show(7));
        Expect.equal(Set.of("id", "displayName", "admin"), body.keySet(), "fields on the wire");
        Expect.equal("Ada Lovelace", body.get("displayName"), "displayName");
        Expect.equal(true, body.get("admin"), "admin flag of Ada");
        Expect.equal(false, wire(new UserApi().show(8)).get("admin"), "admin flag of Bo");
    }

    @Check(id = "list-hides-secrets")
    void listHidesSecrets() {
        for (Object item : new UserApi().list()) {
            Expect.equal(Set.of("id", "displayName", "admin"), wire(item).keySet(),
                "fields on the wire for list()");
        }
    }

    @Check(id = "register-checks-the-email")
    void registerChecksTheEmail() {
        Expect.raises(IllegalArgumentException.class,
            () -> new RegisterRequest("Bo", "Ng", "nope"), "an email without @");
        Expect.raises(IllegalArgumentException.class,
            () -> new RegisterRequest("Bo", "Ng", null), "a null email");
        var api = new UserApi();
        long id = api.register(new RegisterRequest("Cy", "Dee", "cy@x.org"));
        var body = wire(api.show(id));
        Expect.equal("Cy Dee", body.get("displayName"), "the registered user");
        Expect.equal(false, body.get("admin"), "a new user is not an admin");
    }

    @Check(id = "api-returns-dtos-not-entities", kind = Kind.DESIGN)
    void apiReturnsDtosNotEntities() throws Exception {
        Method show = Types.method(Types.named("UserApi"), "show", long.class);
        Expect.isTrue(show.getReturnType() != User.class && show.getReturnType() != Object.class,
            "show should return a response type of its own, not the User entity");
        Method list = Types.method(Types.named("UserApi"), "list");
        Expect.isTrue(list.getGenericReturnType() instanceof ParameterizedType p
                && p.getActualTypeArguments()[0] instanceof Class<?> c && c != User.class,
            "list should return a List of response objects, not of User");
    }

    @Check(id = "dto-is-plain-and-immutable", kind = Kind.DESIGN)
    void dtoIsPlainAndImmutable() {
        Class<?> dto = Types.method(Types.named("UserApi"), "show", long.class).getReturnType();
        Expect.isTrue(dto != User.class, dto.getSimpleName() + " is the entity itself");
        for (Field f : dto.getDeclaredFields()) {
            if (Modifier.isStatic(f.getModifiers())) continue;
            Expect.isTrue(Modifier.isFinal(f.getModifiers()),
                dto.getSimpleName() + "." + f.getName() + " should be final");
            Expect.isTrue(f.getType() != User.class && !List.class.isAssignableFrom(f.getType()),
                dto.getSimpleName() + "." + f.getName() + " carries entity data or a mutable list");
        }
    }

    @Check(id = "mapping-stays-out-of-the-entity", kind = Kind.DESIGN)
    void mappingStaysOutOfTheEntity() {
        var user = Source.type("User");
        Expect.none(user.mentions("RegisterRequest"), "User depends on the request type");
        Expect.isTrue(Types.named("User").getDeclaredMethods().length > 0
                && java.util.Arrays.stream(Types.named("User").getDeclaredMethods())
                    .noneMatch(m -> m.getReturnType() == Types.method(
                        Types.named("UserApi"), "show", long.class).getReturnType()),
            "User should not build the response itself; map it in the DTO or a mapper");
    }
}
