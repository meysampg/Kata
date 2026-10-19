import java.util.List;
import java.util.Map;
import kata.*;

class InterpreterKataTest {
    static final Map<String, Boolean> ENV =
        Map.of("pro", true, "trial", false, "eu", true);

    static final Rule BOOM = flags -> {
        throw new IllegalStateException("evaluated a branch it should skip");
    };

    static Rule flag(String n) { return new Flag(n); }

    static boolean run(Rule rule) { return rule.eval(ENV); }

    @Check(id = "flag-lookup")
    void flagLookup() {
        Expect.equal(true, run(flag("pro")), "a true flag");
        Expect.equal(false, run(flag("trial")), "a false flag");
        Expect.raises(IllegalStateException.class,
            () -> run(flag("ghost")), "a flag that is not in the context");
    }

    @Check(id = "not-and-or")
    void notAndOr() {
        Expect.equal(true, run(new Not(flag("trial"))), "not false");
        Expect.equal(false, run(new Not(flag("pro"))), "not true");
        Expect.equal(true, run(new And(flag("pro"), flag("eu"))), "true and true");
        Expect.equal(false, run(new And(flag("pro"), flag("trial"))), "true and false");
        Expect.equal(true, run(new Or(flag("trial"), flag("eu"))), "false or true");
        Expect.equal(false, run(new Or(flag("trial"), new Not(flag("eu")))), "false or false");
    }

    @Check(id = "short-circuit")
    void shortCircuit() {
        Expect.equal(false, run(new And(flag("trial"), BOOM)), "false and <skipped>");
        Expect.equal(true, run(new Or(flag("pro"), BOOM)), "true or <skipped>");
    }

    @Check(id = "same-tree-many-contexts")
    void sameTreeManyContexts() {
        Rule rule = new And(flag("pro"), new Not(flag("trial")));
        Expect.equal(true, rule.eval(Map.of("pro", true, "trial", false)), "first context");
        Expect.equal(false, rule.eval(Map.of("pro", true, "trial", true)), "second context");
        Expect.equal(false, rule.eval(Map.of("pro", false, "trial", false)), "third context");
    }

    @Check(id = "parse-evaluates")
    void parseEvaluates() {
        Expect.equal(true, run(Rules.parse("pro")), "a lone flag");
        Expect.equal(true, run(Rules.parse("(not trial)")), "(not trial)");
        Expect.equal(false, run(Rules.parse("(and pro (or trial (not eu)))")),
            "(and pro (or trial (not eu)))");
        Expect.equal(true, run(Rules.parse("(and pro (or trial eu))")),
            "(and pro (or trial eu))");
        Expect.equal(true, run(Rules.parse("  ( and   pro eu )  ")),
            "a sentence with extra spaces");
    }

    @Check(id = "parse-rejects-bad-input")
    void parseRejectsBadInput() {
        for (String bad : List.of("", "(and pro)", "(xor pro eu)", "(and pro eu",
                "pro eu", ")", "(not)", "(and pro eu))", "(not a b)")) {
            Expect.raises(IllegalArgumentException.class,
                () -> Rules.parse(bad), "parsing \"" + bad + "\"");
        }
    }

    @Check(id = "nodes-evaluate-themselves", kind = Kind.DESIGN)
    void nodesEvaluateThemselves() {
        for (String name : List.of("Flag", "Not", "And", "Or")) {
            var eval = Source.type(name).method("eval");
            Expect.none(eval.switches(), name + ".eval switches instead of just evaluating");
            Expect.none(eval.instanceofs(), name + ".eval inspects node types");
        }
    }

    @Check(id = "nodes-are-immutable", kind = Kind.DESIGN)
    void nodesAreImmutable() {
        for (String name : List.of("Flag", "Not", "And", "Or")) {
            for (var f : Types.named(name).getDeclaredFields()) {
                if (f.isSynthetic() || java.lang.reflect.Modifier.isStatic(f.getModifiers())) {
                    continue;
                }
                Expect.isTrue(java.lang.reflect.Modifier.isFinal(f.getModifiers()),
                    name + "." + f.getName() + " should be final");
            }
        }
    }

    @Check(id = "parse-builds-the-nodes", kind = Kind.DESIGN)
    void parseBuildsTheNodes() {
        Expect.equal(And.class, Rules.parse("(and pro eu)").getClass(), "(and pro eu)");
        Expect.equal(Or.class, Rules.parse("(or pro eu)").getClass(), "(or pro eu)");
        Expect.equal(Not.class, Rules.parse("(not pro)").getClass(), "(not pro)");
        Expect.equal(Flag.class, Rules.parse("pro").getClass(), "pro");
        Expect.none(Source.type("Rules").calls("eval"),
            "Rules.parse should only build the tree, never evaluate it");
    }

    @Check(id = "operands-are-any-rule", kind = Kind.DESIGN)
    void operandsAreAnyRule() throws Throwable {
        Class<?> rule = Types.named("Rule");
        Object yes = Types.implement(rule, args -> true);
        Object no = Types.implement(rule, args -> false);
        Object and = Types.create(Types.constructor(Types.named("And"), rule, rule), yes, no);
        Object or = Types.create(Types.constructor(Types.named("Or"), rule, rule), yes, no);
        Object not = Types.create(Types.constructor(Types.named("Not"), rule), no);
        Expect.equal(false, ((Rule) and).eval(ENV), "And over rules it has never seen");
        Expect.equal(true, ((Rule) or).eval(ENV), "Or over rules it has never seen");
        Expect.equal(true, ((Rule) not).eval(ENV), "Not over a rule it has never seen");
    }
}
