import com.sun.source.tree.AnnotationTree;
import com.sun.source.tree.AssignmentTree;
import com.sun.source.tree.ClassTree;
import com.sun.source.tree.CompilationUnitTree;
import com.sun.source.tree.ExpressionTree;
import com.sun.source.tree.IdentifierTree;
import com.sun.source.tree.LiteralTree;
import com.sun.source.tree.MemberSelectTree;
import com.sun.source.tree.MethodInvocationTree;
import com.sun.source.tree.MethodTree;
import com.sun.source.tree.NewClassTree;
import com.sun.source.tree.Tree;
import com.sun.source.util.JavacTask;
import com.sun.source.util.SourcePositions;
import com.sun.source.util.TreeScanner;
import com.sun.source.util.Trees;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.IOException;
import java.io.OutputStream;
import java.io.PrintStream;
import java.io.Writer;
import java.lang.management.ManagementFactory;
import java.lang.management.ThreadInfo;
import java.lang.management.ThreadMXBean;
import java.lang.reflect.Constructor;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.net.URL;
import java.net.URLClassLoader;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.stream.Stream;
import javax.tools.Diagnostic;
import javax.tools.DiagnosticCollector;
import javax.tools.JavaCompiler;
import javax.tools.JavaFileObject;
import javax.tools.StandardJavaFileManager;
import javax.tools.StandardLocation;
import javax.tools.ToolProvider;
import kata.Check;
import kata.CheckFailure;
import kata.Context;

/**
 * Compiles the learner's files and the hidden tests in-process, runs every {@code @Check} on its own
 * thread with a timeout, and writes one NDJSON event per line to the report file.
 *
 * <pre>
 * java -cp &lt;harness classes&gt; KataHarness --src DIR --tests DIR --classes DIR --report FILE
 *      [--release 21] [--repeat N]
 * </pre>
 *
 * The process always ends through {@code Runtime.halt}, which also kills threads left behind by
 * checks that timed out.
 */
public final class KataHarness {
    static final int OUTPUT_PER_CHECK = 64 * 1024;
    static final int OUTPUT_PER_RUN = 1024 * 1024;

    // ---------------------------------------------------------------- state

    private static Reporter report;
    private static volatile CheckInfo current;
    private static volatile boolean finished;
    private static final Object FINISH_LOCK = new Object();
    private static final long START = System.nanoTime();

    record CheckInfo(String id, String kind, String file) {}

    record Discovered(String id, String kind, int timeoutMs, int repeat, String className, String methodName,
            String testFile, String blockedReason) {}

    public static void main(String[] args) {
        Map<String, String> opts = new LinkedHashMap<>();
        for (int i = 0; i + 1 < args.length; i += 2) {
            opts.put(args[i], args[i + 1]);
        }
        try {
            report = new Reporter(Path.of(opts.get("--report")));
        } catch (Exception e) {
            System.err.println("cannot open report: " + e);
            Runtime.getRuntime().halt(2);
            return;
        }
        Runtime.getRuntime().addShutdownHook(new Thread(KataHarness::onShutdown, "kata-shutdown"));
        try {
            if (Boolean.getBoolean("kata.test.hang")) {
                Thread.sleep(Long.MAX_VALUE); // test hook: simulates a harness that never answers
            }
            run(opts);
        } catch (Throwable t) {
            report.line("{\"type\":\"error\",\"message\":" + q("harness failure: " + t) + "}");
        }
        finish();
        Runtime.getRuntime().halt(0);
    }

    private static void finish() {
        synchronized (FINISH_LOCK) {
            if (!finished) {
                finished = true;
                report.line("{\"type\":\"done\",\"millis\":" + (System.nanoTime() - START) / 1_000_000 + "}");
            }
        }
    }

    private static void onShutdown() {
        synchronized (FINISH_LOCK) {
            if (finished) {
                return;
            }
            CheckInfo c = current;
            if (c != null) {
                report.line("{\"type\":\"check\",\"id\":" + q(c.id) + ",\"kind\":" + q(c.kind)
                        + ",\"status\":\"exited\",\"message\":"
                        + q("The code called System.exit or halted the JVM during this check")
                        + ",\"millis\":0,\"output\":" + q(Capture.INSTANCE.text()) + "}");
            }
            finished = true;
            report.line("{\"type\":\"done\",\"millis\":" + (System.nanoTime() - START) / 1_000_000 + "}");
        }
    }

    // ---------------------------------------------------------------- main flow

    private static void run(Map<String, String> opts) throws Exception {
        Path srcDir = Path.of(opts.get("--src"));
        Path testDir = Path.of(opts.get("--tests"));
        Path classes = Path.of(opts.get("--classes"));
        String release = opts.getOrDefault("--release", "21");
        int repeatFloor = Integer.parseInt(opts.getOrDefault("--repeat", "1"));
        Files.createDirectories(classes);

        List<File> userFiles = javaFiles(srcDir);
        List<File> tests = javaFiles(testDir);
        List<File> allTestsOnDisk = List.copyOf(tests);
        Set<String> userNames = new java.util.HashSet<>();
        for (File f : userFiles) {
            userNames.add(f.getName());
        }

        // Compile; tests that do not compile are set aside and their checks reported as blocked.
        Map<String, String> blockedFiles = new LinkedHashMap<>();
        Compiled compiled = null;
        for (int attempt = 0; attempt < 3; attempt++) {
            List<File> all = new ArrayList<>(userFiles);
            all.addAll(tests);
            compiled = compile(all, classes, release);
            if (!compiled.hasErrors()) {
                break;
            }
            List<String> badTests = new ArrayList<>();
            for (Diag d : compiled.diags) {
                if (d.error && d.file != null && !userNames.contains(d.file)
                        && tests.stream().anyMatch(t -> t.getName().equals(d.file)) && !badTests.contains(d.file)) {
                    badTests.add(d.file);
                    blockedFiles.putIfAbsent(d.file, sanitize(d.message));
                }
            }
            if (badTests.isEmpty()) {
                break; // errors in the learner's files
            }
            tests.removeIf(t -> badTests.contains(t.getName()));
        }

        List<Diag> userDiags = new ArrayList<>();
        for (Diag d : compiled.diags) {
            if (d.file != null && userNames.contains(d.file) && (d.error || d.warning)) {
                userDiags.add(d);
            }
        }
        boolean userErrors = userDiags.stream().anyMatch(d -> d.error);
        if (compiled.hasErrors() && !userErrors) {
            // Only hidden test files are broken and none could be set aside: report generically.
            userDiags.add(new Diag(true, false, null, 0, 0, -1, -1, "internal", "The tests could not be compiled"));
            userErrors = true;
        }

        // javac discards the trees it generates classes from, so parse again for structural queries.
        List<File> everything = new ArrayList<>(userFiles);
        everything.addAll(allTestsOnDisk);
        List<Context.Unit> parsed = parseAll(everything, release);
        List<Context.Unit> userUnits = new ArrayList<>();
        for (Context.Unit u : parsed) {
            if (userNames.contains(u.fileName())) {
                userUnits.add(u);
            }
        }
        if (!userErrors) {
            userDiags.addAll(policyScan(userUnits));
            userErrors = userDiags.stream().anyMatch(d -> d.error);
        }
        report.line("{\"type\":\"compile\",\"ok\":" + !userErrors + ",\"diagnostics\":" + diagsJson(userDiags) + "}");
        if (userErrors) {
            return;
        }

        // Discover checks from the trees (source order), including the blocked test files.
        List<Discovered> checks = new ArrayList<>();
        for (Context.Unit u : parsed) {
            if (!userNames.contains(u.fileName())) {
                discover(u.tree(), u.fileName(), blockedFiles.get(u.fileName()), checks);
            }
        }

        URLClassLoader loader = new URLClassLoader(new URL[] {classes.toUri().toURL()},
                KataHarness.class.getClassLoader());
        Context.install(loader, userUnits, Context.collectTypeNames(userUnits));
        Capture.install();

        boolean earlierTimeout = false;
        for (Discovered d : checks) {
            if (d.blockedReason != null) {
                report.line("{\"type\":\"check\",\"id\":" + q(d.id) + ",\"kind\":" + q(d.kind)
                        + ",\"status\":\"blocked\",\"message\":" + q("needs: " + d.blockedReason)
                        + ",\"millis\":0}");
                continue;
            }
            boolean timedOut = runCheck(d, loader, userNames, Math.max(d.repeat, repeatFloor), earlierTimeout);
            earlierTimeout |= timedOut;
        }
    }

    // ---------------------------------------------------------------- running checks

    private static boolean runCheck(Discovered d, ClassLoader loader, Set<String> userNames, int repeat,
            boolean affected) {
        current = new CheckInfo(d.id, d.kind, d.testFile);
        Capture.INSTANCE.begin();
        long t0 = System.nanoTime();
        String status = "pass";
        String message = "";
        String file = null;
        int line = 0;
        int failedRun = 0;
        boolean timedOut = false;
        try {
            Class<?> cls = Class.forName(d.className, false, loader);
            Method method = null;
            for (Method m : cls.getDeclaredMethods()) {
                Check c = m.getAnnotation(Check.class);
                if (c != null && c.id().equals(d.id)) {
                    method = m;
                }
            }
            if (method == null) {
                throw new IllegalStateException("check method not found for " + d.id);
            }
            method.setAccessible(true);
            Constructor<?> ctor = cls.getDeclaredConstructor();
            ctor.setAccessible(true);
            for (int i = 1; i <= repeat; i++) {
                Execution ex = new Execution(ctor, method);
                Thread t = new Thread(null, ex, "kata-check-" + d.id, 0);
                t.setDaemon(true);
                t.start();
                t.join(d.timeoutMs);
                if (t.isAlive()) {
                    status = "timeout";
                    timedOut = true;
                    failedRun = i;
                    message = "Timed out after " + d.timeoutMs + " ms" + describeStuck(t);
                    StackTraceElement[] st = t.getStackTrace();
                    StackTraceElement top = firstUser(st, userNames);
                    if (top != null) {
                        file = top.getFileName();
                        line = top.getLineNumber();
                        message += " (stuck near " + file + ":" + line + ")";
                    }
                    break;
                }
                Throwable err = ex.error;
                if (err != null) {
                    failedRun = i;
                    if (err instanceof CheckFailure cf) {
                        status = "fail";
                        message = String.valueOf(cf.getMessage());
                        file = cf.file();
                        line = cf.line();
                        if (file == null) {
                            StackTraceElement top = firstUser(cf.getStackTrace(), userNames);
                            if (top != null) {
                                file = top.getFileName();
                                line = top.getLineNumber();
                            }
                        }
                    } else {
                        status = "error";
                        message = err.getClass().getName() + (err.getMessage() == null ? "" : ": " + err.getMessage());
                        StackTraceElement top = firstUser(err.getStackTrace(), userNames);
                        if (top != null) {
                            file = top.getFileName();
                            line = top.getLineNumber();
                        }
                    }
                    break;
                }
            }
        } catch (Throwable t) {
            status = "error";
            Throwable cause = t instanceof InvocationTargetException ite && ite.getCause() != null ? ite.getCause() : t;
            message = cause.getClass().getName() + (cause.getMessage() == null ? "" : ": " + cause.getMessage());
        }
        long ms = (System.nanoTime() - t0) / 1_000_000;
        String output = Capture.INSTANCE.end();
        StringBuilder sb = new StringBuilder("{\"type\":\"check\",\"id\":").append(q(d.id)).append(",\"kind\":")
                .append(q(d.kind)).append(",\"status\":").append(q(status)).append(",\"message\":").append(q(message));
        if (file != null) {
            sb.append(",\"file\":").append(q(file)).append(",\"line\":").append(line);
        }
        sb.append(",\"millis\":").append(ms).append(",\"output\":").append(q(output));
        if (failedRun > 0) {
            sb.append(",\"run\":").append(failedRun);
        }
        if (affected) {
            sb.append(",\"affected\":true");
        }
        sb.append('}');
        report.line(sb.toString());
        current = null;
        return timedOut;
    }

    private static final class Execution implements Runnable {
        private final Constructor<?> ctor;
        private final Method method;
        volatile Throwable error;

        Execution(Constructor<?> ctor, Method method) {
            this.ctor = ctor;
            this.method = method;
        }

        @Override
        public void run() {
            try {
                Object instance = ctor.newInstance();
                method.invoke(instance);
            } catch (InvocationTargetException e) {
                error = e.getCause() != null ? e.getCause() : e;
            } catch (Throwable t) {
                error = t;
            }
        }
    }

    private static StackTraceElement firstUser(StackTraceElement[] stack, Set<String> userNames) {
        for (StackTraceElement e : stack) {
            if (e.getFileName() != null && userNames.contains(e.getFileName()) && e.getLineNumber() > 0) {
                return e;
            }
        }
        return null;
    }

    private static String describeStuck(Thread t) {
        StringBuilder sb = new StringBuilder();
        try {
            ThreadMXBean bean = ManagementFactory.getThreadMXBean();
            long[] ids = bean.findDeadlockedThreads();
            if (ids != null && ids.length > 0) {
                sb.append(". Deadlock: ");
                ThreadInfo[] infos = bean.getThreadInfo(ids, true, true);
                List<String> parts = new ArrayList<>();
                for (ThreadInfo info : infos) {
                    if (info != null) {
                        parts.add("thread " + info.getThreadName() + " waits for " + info.getLockName()
                                + " held by " + info.getLockOwnerName());
                    }
                }
                sb.append(String.join("; ", parts));
            }
        } catch (Throwable ignored) {
            // diagnostics only
        }
        return sb.toString();
    }

    // ---------------------------------------------------------------- compile

    record Diag(boolean error, boolean warning, String file, long line, long column, long start, long end,
            String code, String message) {}

    static final class Compiled {
        final List<Diag> diags = new ArrayList<>();

        boolean hasErrors() {
            return diags.stream().anyMatch(d -> d.error);
        }
    }

    private static Compiled compile(List<File> files, Path classes, String release) throws IOException {
        Compiled out = new Compiled();
        JavaCompiler compiler = ToolProvider.getSystemJavaCompiler();
        DiagnosticCollector<JavaFileObject> diags = new DiagnosticCollector<>();
        try (StandardJavaFileManager fm = compiler.getStandardFileManager(diags, Locale.ENGLISH,
                StandardCharsets.UTF_8)) {
            fm.setLocation(StandardLocation.CLASS_OUTPUT, List.of(classes.toFile()));
            List<File> cp = new ArrayList<>();
            for (String part : System.getProperty("java.class.path", "").split(File.pathSeparator)) {
                if (!part.isEmpty()) {
                    cp.add(new File(part));
                }
            }
            fm.setLocation(StandardLocation.CLASS_PATH, cp);
            List<String> options = List.of("--release", release, "-Xlint:all,-auxiliaryclass", "-proc:none", "-g", "-encoding",
                    "UTF-8");
            JavacTask task = (JavacTask) compiler.getTask(null, fm, diags, options, null,
                    fm.getJavaFileObjectsFromFiles(files));
            try {
                task.parse();
                task.analyze();
                if (diags.getDiagnostics().stream().noneMatch(d -> d.getKind() == Diagnostic.Kind.ERROR)) {
                    task.generate();
                }
            } catch (RuntimeException e) {
                out.diags.add(new Diag(true, false, null, 0, 0, -1, -1, "internal", "compiler failure: " + e));
            }
        }
        for (Diagnostic<? extends JavaFileObject> d : diags.getDiagnostics()) {
            boolean error = d.getKind() == Diagnostic.Kind.ERROR;
            boolean warning = d.getKind() == Diagnostic.Kind.WARNING || d.getKind() == Diagnostic.Kind.MANDATORY_WARNING;
            if (!error && !warning) {
                continue;
            }
            String file = d.getSource() == null ? null : Path.of(d.getSource().getName()).getFileName().toString();
            out.diags.add(new Diag(error, warning, file, d.getLineNumber(), d.getColumnNumber(),
                    d.getStartPosition(), d.getEndPosition(), String.valueOf(d.getCode()),
                    d.getMessage(Locale.ENGLISH)));
        }
        return out;
    }

    private static List<Context.Unit> parseAll(List<File> files, String release) {
        List<Context.Unit> out = new ArrayList<>();
        try {
            JavaCompiler compiler = ToolProvider.getSystemJavaCompiler();
            try (StandardJavaFileManager fm = compiler.getStandardFileManager(d -> { }, Locale.ENGLISH,
                    StandardCharsets.UTF_8)) {
                JavacTask task = (JavacTask) compiler.getTask(null, fm, d -> { }, List.of("--release", release,
                        "-proc:none", "-encoding", "UTF-8"), null, fm.getJavaFileObjectsFromFiles(files));
                SourcePositions positions = Trees.instance(task).getSourcePositions();
                for (CompilationUnitTree cu : task.parse()) {
                    String name = Path.of(cu.getSourceFile().getName()).getFileName().toString();
                    out.add(new Context.Unit(name, cu, positions));
                }
            }
        } catch (Exception e) {
            // unparsable files simply contribute no trees
        }
        return out;
    }

    /** Hides hidden-test internals: keeps the first line and the missing symbol, not the location. */
    static String sanitize(String message) {
        List<String> keep = new ArrayList<>();
        for (String raw : message.split("\n")) {
            String l = raw.trim();
            if (l.isEmpty() || l.startsWith("location:")) {
                continue;
            }
            keep.add(l);
        }
        return String.join(" ", keep.subList(0, Math.min(2, keep.size()))).replaceAll("\\s+", " ");
    }

    // ---------------------------------------------------------------- policy

    private static List<Diag> policyScan(List<Context.Unit> units) {
        List<Diag> out = new ArrayList<>();
        for (Context.Unit u : units) {
            new TreeScanner<Void, Void>() {
                void flag(Tree node, String what) {
                    long start = u.positions().getStartPosition(u.tree(), node);
                    long end = u.positions().getEndPosition(u.tree(), node);
                    long line = start < 0 ? 0 : u.tree().getLineMap().getLineNumber(start);
                    long col = start < 0 ? 0 : u.tree().getLineMap().getColumnNumber(start);
                    out.add(new Diag(true, false, u.fileName(), line, col, start, end, "kata.policy",
                            what + " is not allowed in a kata"));
                }

                @Override
                public Void visitMethodInvocation(MethodInvocationTree node, Void p) {
                    if (node.getMethodSelect() instanceof MemberSelectTree ms) {
                        String name = ms.getIdentifier().toString();
                        String recv = ms.getExpression().toString();
                        if (name.equals("exit") && (recv.equals("System") || recv.endsWith(".System")
                                || recv.contains("Runtime"))) {
                            flag(node, "Calling exit");
                        } else if (name.equals("halt") && recv.contains("Runtime")) {
                            flag(node, "Calling Runtime.halt");
                        } else if (name.equals("exec") && recv.contains("Runtime")) {
                            flag(node, "Starting a process");
                        }
                    }
                    return super.visitMethodInvocation(node, p);
                }

                @Override
                public Void visitNewClass(NewClassTree node, Void p) {
                    String id = node.getIdentifier().toString();
                    if (id.equals("ProcessBuilder") || id.endsWith(".ProcessBuilder")) {
                        flag(node, "Starting a process");
                    }
                    return super.visitNewClass(node, p);
                }
            }.scan(u.tree(), null);
        }
        return out;
    }

    // ---------------------------------------------------------------- discovery

    private static void discover(CompilationUnitTree tree, String fileName, String blocked, List<Discovered> out) {
        String pkg = tree.getPackageName() == null ? "" : tree.getPackageName() + ".";
        for (Tree decl : tree.getTypeDecls()) {
                        if (decl instanceof ClassTree ct) {
                collect(ct, pkg + ct.getSimpleName(), fileName, blocked, out);
            }
        }
    }

    private static void collect(ClassTree ct, String binary, String fileName, String blocked, List<Discovered> out) {
        for (Tree member : ct.getMembers()) {
            if (member instanceof MethodTree mt) {
                for (AnnotationTree a : mt.getModifiers().getAnnotations()) {
                    String an = a.getAnnotationType().toString();
                    if (!(an.equals("Check") || an.equals("kata.Check"))) {
                        continue;
                    }
                    String id = null;
                    String kind = "behaviour";
                    int timeout = 2000;
                    int repeat = 1;
                    for (ExpressionTree arg : a.getArguments()) {
                        if (arg instanceof AssignmentTree as) {
                            String key = as.getVariable().toString();
                            ExpressionTree v = as.getExpression();
                            switch (key) {
                                case "id" -> id = v instanceof LiteralTree l ? String.valueOf(l.getValue()) : null;
                                case "kind" -> kind = v.toString().toLowerCase(Locale.ROOT).endsWith("design")
                                        ? "design" : "behaviour";
                                case "timeoutMs" -> timeout = intOf(v, 2000);
                                case "repeat" -> repeat = intOf(v, 1);
                                default -> { }
                            }
                        }
                    }
                    if (id != null) {
                        out.add(new Discovered(id, kind, timeout, repeat, binary, mt.getName().toString(), fileName,
                                blocked));
                    }
                }
            } else if (member instanceof ClassTree inner) {
                collect(inner, binary + "$" + inner.getSimpleName(), fileName, blocked, out);
            }
        }
    }

    private static int intOf(ExpressionTree e, int fallback) {
        return e instanceof LiteralTree l && l.getValue() instanceof Number n ? n.intValue() : fallback;
    }

    private static List<File> javaFiles(Path dir) throws IOException {
        if (!Files.isDirectory(dir)) {
            return new ArrayList<>();
        }
        try (Stream<Path> s = Files.list(dir)) {
            List<File> files = new ArrayList<>(s.filter(p -> p.getFileName().toString().endsWith(".java"))
                    .sorted(Comparator.comparing(p -> p.getFileName().toString())).map(Path::toFile).toList());
            return files;
        }
    }

    // ---------------------------------------------------------------- json

    private static String diagsJson(List<Diag> diags) {
        StringBuilder sb = new StringBuilder("[");
        for (int i = 0; i < diags.size(); i++) {
            Diag d = diags.get(i);
            if (i > 0) {
                sb.append(',');
            }
            sb.append("{\"severity\":").append(q(d.error ? "error" : "warning"));
            if (d.file != null) {
                sb.append(",\"file\":").append(q(d.file));
            }
            sb.append(",\"line\":").append(Math.max(0, d.line)).append(",\"column\":").append(Math.max(0, d.column))
                    .append(",\"start\":").append(d.start).append(",\"end\":").append(d.end).append(",\"code\":")
                    .append(q(d.code)).append(",\"message\":").append(q(d.message)).append('}');
        }
        return sb.append(']').toString();
    }

    static String q(String s) {
        if (s == null) {
            return "null";
        }
        StringBuilder b = new StringBuilder(s.length() + 2).append('"');
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            switch (c) {
                case '"' -> b.append("\\\"");
                case '\\' -> b.append("\\\\");
                case '\n' -> b.append("\\n");
                case '\r' -> b.append("\\r");
                case '\t' -> b.append("\\t");
                default -> {
                    if (c < 0x20) {
                        b.append(String.format("\\u%04x", (int) c));
                    } else {
                        b.append(c);
                    }
                }
            }
        }
        return b.append('"').toString();
    }

    /** Appends one flushed line per event. */
    static final class Reporter {
        private final Writer out;

        Reporter(Path path) throws IOException {
            out = Files.newBufferedWriter(path, StandardCharsets.UTF_8);
        }

        synchronized void line(String json) {
            try {
                out.write(json);
                out.write('\n');
                out.flush();
            } catch (IOException ignored) {
                // nothing sensible left to do
            }
        }
    }

    /** Thread-safe capped capture of System.out and System.err, one buffer per check. */
    static final class Capture extends OutputStream {
        static final Capture INSTANCE = new Capture();
        private final ByteArrayOutputStream buffer = new ByteArrayOutputStream();
        private int perCheck;
        private long perRun;
        private boolean truncated;

        static void install() {
            PrintStream ps = new PrintStream(INSTANCE, true, StandardCharsets.UTF_8);
            System.setOut(ps);
            System.setErr(ps);
            System.setIn(new java.io.ByteArrayInputStream(new byte[0]));
        }

        synchronized void begin() {
            buffer.reset();
            perCheck = 0;
            truncated = false;
        }

        synchronized String end() {
            String s = text();
            buffer.reset();
            return s;
        }

        synchronized String text() {
            String s = buffer.toString(StandardCharsets.UTF_8);
            return truncated ? s + "\n[output truncated]" : s;
        }

        @Override
        public synchronized void write(int b) {
            write(new byte[] {(byte) b}, 0, 1);
        }

        @Override
        public synchronized void write(byte[] b, int off, int len) {
            int room = Math.min(OUTPUT_PER_CHECK - perCheck, (int) Math.min(Integer.MAX_VALUE, OUTPUT_PER_RUN - perRun));
            if (room <= 0) {
                truncated = true;
                return;
            }
            int n = Math.min(room, len);
            buffer.write(b, off, n);
            perCheck += n;
            perRun += n;
            if (n < len) {
                truncated = true;
            }
        }
    }

    private KataHarness() {}
}
