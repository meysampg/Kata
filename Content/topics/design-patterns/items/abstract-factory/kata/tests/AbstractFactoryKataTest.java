import java.lang.reflect.Field;
import java.lang.reflect.Modifier;
import kata.*;

class AbstractFactoryKataTest {
    @Check(id = "local-family")
    void localFamily() {
        Infra infra = new LocalInfra();
        Expect.equal("file:/data/a.csv", infra.blobs().put("a.csv", "x"), "local blob location");
        Expect.equal("mem-bus/t: m", infra.events().publish("t", "m"), "local bus receipt");
    }

    @Check(id = "cloud-family")
    void cloudFamily() {
        Infra infra = new CloudInfra("acme");
        Expect.equal("s3://acme/a.csv", infra.blobs().put("a.csv", "x"), "cloud blob location");
        Expect.equal("sns/t: m", infra.events().publish("t", "m"), "cloud bus receipt");
    }

    @Check(id = "cloud-needs-a-bucket")
    void cloudNeedsABucket() {
        Expect.raises(IllegalArgumentException.class, () -> new CloudInfra(" "), "a blank bucket");
        Expect.raises(IllegalArgumentException.class, () -> new CloudInfra(null), "a null bucket");
    }

    @Check(id = "uploader-follows-its-family")
    void uploaderFollowsItsFamily() {
        Expect.equal("mem-bus/uploaded: file:/data/q3.csv",
            new Uploader(new LocalInfra()).upload("q3.csv", "..."), "upload on local infra");
        Expect.equal("sns/uploaded: s3://acme/q3.csv",
            new Uploader(new CloudInfra("acme")).upload("q3.csv", "..."), "upload on cloud infra");
    }

    @Check(id = "env-selects-a-family")
    void envSelectsAFamily() {
        Expect.equal("mem-bus/uploaded: file:/data/k",
            new Uploader(Infras.forEnv("dev")).upload("k", ""), "dev");
        Expect.equal("sns/uploaded: s3://acme-prod/k",
            new Uploader(Infras.forEnv("prod")).upload("k", ""), "prod");
        Expect.raises(IllegalArgumentException.class, () -> Infras.forEnv("qa"), "an unknown env");
    }

    @Check(id = "families-implement-the-factory", kind = Kind.DESIGN)
    void familiesImplementTheFactory() {
        Class<?> infra = Types.named("Infra");
        Expect.isTrue(infra.isAssignableFrom(Types.named("LocalInfra")),
            "LocalInfra should implement Infra");
        Expect.isTrue(infra.isAssignableFrom(Types.named("CloudInfra")),
            "CloudInfra should implement Infra");
    }

    @Check(id = "uploader-holds-only-the-factory", kind = Kind.DESIGN)
    void uploaderHoldsOnlyTheFactory() {
        Class<?> uploader = Types.named("Uploader");
        Field f = Types.onlyFieldOfType(uploader, Types.named("Infra"));
        Expect.isTrue(Modifier.isPrivate(f.getModifiers()) && Modifier.isFinal(f.getModifiers()),
            "Uploader." + f.getName() + " should be private final");
        Types.constructor(uploader, Types.named("Infra"));
    }

    @Check(id = "uploader-ignores-concrete-families", kind = Kind.DESIGN)
    void uploaderIgnoresConcreteFamilies() {
        var uploader = Source.type("Uploader");
        Expect.none(uploader.mentions("LocalInfra"), "Uploader still names LocalInfra");
        Expect.none(uploader.mentions("CloudInfra"), "Uploader still names CloudInfra");
        Expect.none(uploader.instanceofs(), "Uploader inspects the family's concrete type");
        Expect.none(uploader.comparedStrings(), "Uploader still branches on the environment");
    }

    @Check(id = "families-do-not-mix", kind = Kind.DESIGN)
    void familiesDoNotMix() {
        Expect.none(Source.type("LocalInfra").mentions("CloudInfra"),
            "LocalInfra should not touch the cloud family");
        Expect.none(Source.type("CloudInfra").mentions("LocalInfra"),
            "CloudInfra should not touch the local family");
        Expect.none(Source.type("LocalInfra").mentions("sns"), "LocalInfra mentions sns");
    }
}
