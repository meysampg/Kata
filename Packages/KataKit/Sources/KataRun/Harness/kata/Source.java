package kata;

import com.sun.source.tree.AssignmentTree;
import com.sun.source.tree.BinaryTree;
import com.sun.source.tree.CaseTree;
import com.sun.source.tree.ClassTree;
import com.sun.source.tree.ExpressionTree;
import com.sun.source.tree.IdentifierTree;
import com.sun.source.tree.InstanceOfTree;
import com.sun.source.tree.LiteralTree;
import com.sun.source.tree.MemberSelectTree;
import com.sun.source.tree.MethodInvocationTree;
import com.sun.source.tree.MethodTree;
import com.sun.source.tree.NewClassTree;
import com.sun.source.tree.ParameterizedTypeTree;
import com.sun.source.tree.SwitchExpressionTree;
import com.sun.source.tree.SwitchTree;
import com.sun.source.tree.SynchronizedTree;
import com.sun.source.tree.Tree;
import com.sun.source.util.TreePath;
import com.sun.source.util.TreePathScanner;
import com.sun.source.util.TreeScanner;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import javax.lang.model.element.Modifier;

/**
 * Structural questions about the learner's source, answered from the parse trees (no types are
 * resolved, so matching is by simple name).
 */
public final class Source {
    private Source() {}

    /** The class (or interface, record, enum) with this simple name, wherever it is declared. */
    public static Shape type(String name) {
        for (Context.Unit u : Context.units()) {
            List<ClassTree> found = new ArrayList<>();
            new TreeScanner<Void, Void>() {
                @Override
                public Void visitClass(ClassTree node, Void p) {
                    if (node.getSimpleName().contentEquals(name)) {
                        found.add(node);
                    }
                    return super.visitClass(node, p);
                }
            }.scan(u.tree(), null);
            if (!found.isEmpty()) {
                return new Shape(name, u, List.of(found.get(0)));
            }
        }
        throw new CheckFailure("No type named " + name + " in your files");
    }

    /** A part of the source (a type or some of its methods) that can be queried. */
    public static final class Shape {
        private final String name;
        private final Context.Unit unit;
        private final List<? extends Tree> roots;
        private Facts facts;

        private Shape(String name, Context.Unit unit, List<? extends Tree> roots) {
            this.name = name;
            this.unit = unit;
            this.roots = roots;
        }

        /** The methods with this name (all overloads). */
        public Shape method(String methodName) {
            List<MethodTree> found = new ArrayList<>();
            for (Tree root : roots) {
                new TreeScanner<Void, Void>() {
                    @Override
                    public Void visitMethod(MethodTree node, Void p) {
                        if (node.getName().contentEquals(methodName)) {
                            found.add(node);
                        }
                        return super.visitMethod(node, p);
                    }
                }.scan(root, null);
            }
            if (found.isEmpty()) {
                throw new CheckFailure(name + " has no method named " + methodName);
            }
            return new Shape(name + "." + methodName, unit, found);
        }

        public List<Hit> switches() {
            return facts().switches;
        }

        public List<Hit> instanceofs() {
            return facts().instanceofs;
        }

        /** String literals compared with equals, equalsIgnoreCase, ==, != or used as case labels. */
        public List<Hit> comparedStrings() {
            return facts().comparedStrings;
        }

        public List<Hit> calls(String methodName) {
            return facts().calls.getOrDefault(methodName, List.of());
        }

        /** Reads of a field by simple name (assignments to it are not reads). */
        public List<Hit> fieldReads(String field) {
            return facts().fieldReads.getOrDefault(field, List.of());
        }

        public List<Hit> news(String typeName) {
            return facts().news.getOrDefault(typeName, List.of());
        }

        public List<Hit> mentions(String identifier) {
            return facts().mentions.getOrDefault(identifier, List.of());
        }

        private Facts facts() {
            if (facts == null) {
                Facts f = new Facts();
                for (Tree root : roots) {
                    f.scan(new TreePath(new TreePath(unit.tree()), root), unit);
                }
                facts = f;
            }
            return facts;
        }
    }

    private static final class Facts extends TreePathScanner<Void, Context.Unit> {
        final List<Hit> switches = new ArrayList<>();
        final List<Hit> instanceofs = new ArrayList<>();
        final List<Hit> comparedStrings = new ArrayList<>();
        final Map<String, List<Hit>> calls = new LinkedHashMap<>();
        final Map<String, List<Hit>> fieldReads = new LinkedHashMap<>();
        final Map<String, List<Hit>> news = new LinkedHashMap<>();
        final Map<String, List<Hit>> mentions = new LinkedHashMap<>();
        private int syncDepth;

        private Hit hit(Tree t, Context.Unit u, String text) {
            long pos = u.positions().getStartPosition(u.tree(), t);
            long line = pos < 0 ? 0 : u.tree().getLineMap().getLineNumber(pos);
            long col = pos < 0 ? 0 : u.tree().getLineMap().getColumnNumber(pos);
            return new Hit(u.fileName(), (int) line, (int) col, syncDepth > 0, text);
        }

        private static void add(Map<String, List<Hit>> m, String key, Hit h) {
            m.computeIfAbsent(key, k -> new ArrayList<>()).add(h);
        }

        @Override
        public Void visitMethod(MethodTree node, Context.Unit u) {
            boolean sync = node.getModifiers().getFlags().contains(Modifier.SYNCHRONIZED);
            if (sync) {
                syncDepth++;
            }
            try {
                return super.visitMethod(node, u);
            } finally {
                if (sync) {
                    syncDepth--;
                }
            }
        }

        @Override
        public Void visitSynchronized(SynchronizedTree node, Context.Unit u) {
            scan(node.getExpression(), u);
            syncDepth++;
            try {
                scan(node.getBlock(), u);
            } finally {
                syncDepth--;
            }
            return null;
        }

        @Override
        public Void visitSwitch(SwitchTree node, Context.Unit u) {
            switches.add(hit(node, u, "switch"));
            return super.visitSwitch(node, u);
        }

        @Override
        public Void visitSwitchExpression(SwitchExpressionTree node, Context.Unit u) {
            switches.add(hit(node, u, "switch"));
            return super.visitSwitchExpression(node, u);
        }

        @Override
        public Void visitInstanceOf(InstanceOfTree node, Context.Unit u) {
            instanceofs.add(hit(node, u, "instanceof"));
            return super.visitInstanceOf(node, u);
        }

        @Override
        public Void visitCase(CaseTree node, Context.Unit u) {
            for (ExpressionTree e : node.getExpressions()) {
                if (e instanceof LiteralTree l && l.getValue() instanceof String s) {
                    comparedStrings.add(hit(e, u, "\"" + s + "\""));
                }
            }
            return super.visitCase(node, u);
        }

        @Override
        public Void visitBinary(BinaryTree node, Context.Unit u) {
            Tree.Kind k = node.getKind();
            if (k == Tree.Kind.EQUAL_TO || k == Tree.Kind.NOT_EQUAL_TO) {
                for (ExpressionTree side : List.of(node.getLeftOperand(), node.getRightOperand())) {
                    if (side instanceof LiteralTree l && l.getValue() instanceof String s) {
                        comparedStrings.add(hit(side, u, "\"" + s + "\""));
                    }
                }
            }
            return super.visitBinary(node, u);
        }

        @Override
        public Void visitMethodInvocation(MethodInvocationTree node, Context.Unit u) {
            String name = null;
            ExpressionTree select = node.getMethodSelect();
            ExpressionTree receiver = null;
            if (select instanceof IdentifierTree id) {
                name = id.getName().toString();
            } else if (select instanceof MemberSelectTree ms) {
                name = ms.getIdentifier().toString();
                receiver = ms.getExpression();
            }
            if (name != null) {
                add(calls, name, hit(node, u, name + "()"));
                add(mentions, name, hit(node, u, name));
                if (name.equals("equals") || name.equals("equalsIgnoreCase") || name.equals("contentEquals")) {
                    List<ExpressionTree> operands = new ArrayList<>(node.getArguments());
                    if (receiver != null) {
                        operands.add(receiver);
                    }
                    for (ExpressionTree e : operands) {
                        if (e instanceof LiteralTree l && l.getValue() instanceof String s) {
                            comparedStrings.add(hit(e, u, "\"" + s + "\""));
                        }
                    }
                }
            }
            // Do not count the method name itself as an identifier or field read.
            if (select instanceof MemberSelectTree ms) {
                scan(ms.getExpression(), u);
            }
            scan(node.getTypeArguments(), u);
            scan(node.getArguments(), u);
            return null;
        }

        @Override
        public Void visitNewClass(NewClassTree node, Context.Unit u) {
            String type = simpleName(node.getIdentifier());
            if (type != null) {
                add(news, type, hit(node, u, "new " + type));
            }
            return super.visitNewClass(node, u);
        }

        @Override
        public Void visitIdentifier(IdentifierTree node, Context.Unit u) {
            String name = node.getName().toString();
            Hit h = hit(node, u, name);
            add(mentions, name, h);
            Tree parent = getCurrentPath().getParentPath().getLeaf();
            boolean written = parent instanceof AssignmentTree a && a.getVariable() == node;
            if (!written) {
                add(fieldReads, name, h);
            }
            return null;
        }

        @Override
        public Void visitMemberSelect(MemberSelectTree node, Context.Unit u) {
            String name = node.getIdentifier().toString();
            Hit h = hit(node, u, name);
            add(mentions, name, h);
            Tree parent = getCurrentPath().getParentPath().getLeaf();
            boolean written = parent instanceof AssignmentTree a && a.getVariable() == node;
            if (!written) {
                add(fieldReads, name, h);
            }
            return super.visitMemberSelect(node, u);
        }

        private static String simpleName(Tree t) {
            if (t instanceof IdentifierTree id) {
                return id.getName().toString();
            }
            if (t instanceof MemberSelectTree ms) {
                return ms.getIdentifier().toString();
            }
            if (t instanceof ParameterizedTypeTree p) {
                return simpleName(p.getType());
            }
            return null;
        }
    }
}
