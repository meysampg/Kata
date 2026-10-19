import java.util.Map;

// Given. Every node of the rule tree is a Rule.
interface Rule {
    boolean eval(Map<String, Boolean> flags);
}
