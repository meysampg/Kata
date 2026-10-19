package kata;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * Marks a test method as one kata check. The order of checks is the order of the methods
 * in the source file.
 */
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.METHOD)
public @interface Check {
    /** Kebab-case id; must match the id listed in kata.json. */
    String id();

    Kind kind() default Kind.BEHAVIOUR;

    /** Wall-clock limit for one execution of the check. */
    int timeoutMs() default 2000;

    /** How many times the check runs; it passes only if every run passes. */
    int repeat() default 1;
}
