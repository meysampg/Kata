import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.PrintStream;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.net.URL;
import java.net.URLClassLoader;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;
import java.util.stream.Stream;
import javax.tools.*;

/**
 * Compiles and runs Kata's Java snippets in one JVM.
 *
 * Usage: java Tools/JavaCheck.java <dir>
 *
 * Every subdirectory of <dir> is a unit: its .java files are compiled together with
 * --release 21 -Xlint:all (warnings are reported, errors fail). If the unit has an
 * expected.txt, Main.main is run in-process with stdout captured and compared with it
 * (trailing whitespace ignored). Prints a JSON report; exits 1 if any unit fails.
 */
public class JavaCheck {
    static final int RELEASE = 21;
    static final long RUN_TIMEOUT_MS = 10_000;

    public static void main(String[] args) throws Exception {
        if (args.length != 1) {
            System.err.println("usage: java Tools/JavaCheck.java <dir>");
            System.exit(2);
        }
        Path root = Path.of(args[0]);
        List<Path> units = new ArrayList<>();
        try (Stream<Path> s = Files.list(root)) {
            s.filter(Files::isDirectory).sorted().forEach(units::add);
        }
        JavaCompiler compiler = ToolProvider.getSystemJavaCompiler();
        if (compiler == null) {
            System.err.println("no system Java compiler (run with a JDK)");
            System.exit(2);
        }
        PrintStream realOut = System.out;
        StringBuilder json = new StringBuilder("{\"units\":[");
        boolean allOk = true;
        for (int i = 0; i < units.size(); i++) {
            Result r = check(compiler, units.get(i));
            allOk &= r.ok;
            if (i > 0) json.append(',');
            r.appendTo(json);
        }
        json.append("],\"ok\":").append(allOk).append('}');
        realOut.println(json);
        System.exit(allOk ? 0 : 1);
    }

    record Diag(String kind, String file, long line, String message) {}

    static class Result {
        String name;
        boolean ok = true;
        List<Diag> diagnostics = new ArrayList<>();
        String error, output, expected;

        void appendTo(StringBuilder b) {
            b.append("{\"name\":").append(q(name)).append(",\"ok\":").append(ok).append(",\"diagnostics\":[");
            for (int i = 0; i < diagnostics.size(); i++) {
                Diag d = diagnostics.get(i);
                if (i > 0) b.append(',');
                b.append("{\"kind\":").append(q(d.kind));
                if (d.file != null) b.append(",\"file\":").append(q(d.file));
                if (d.line > 0) b.append(",\"line\":").append(d.line);
                b.append(",\"message\":").append(q(d.message)).append('}');
            }
            b.append(']');
            if (error != null) b.append(",\"error\":").append(q(error));
            if (output != null) b.append(",\"output\":").append(q(output));
            if (expected != null) b.append(",\"expected\":").append(q(expected));
            b.append('}');
        }
    }

    static Result check(JavaCompiler compiler, Path unit) throws IOException {
        Result r = new Result();
        r.name = unit.getFileName().toString();
        List<Path> sources;
        try (Stream<Path> s = Files.walk(unit)) {
            sources = s.filter(p -> p.toString().endsWith(".java")).sorted().toList();
        }
        if (sources.isEmpty()) {
            r.ok = false;
            r.error = "no .java files";
            return r;
        }
        Path out = Files.createTempDirectory("kata-javacheck-out");
        try {
            DiagnosticCollector<JavaFileObject> diags = new DiagnosticCollector<>();
            try (StandardJavaFileManager fm = compiler.getStandardFileManager(diags, null, StandardCharsets.UTF_8)) {
                List<String> options = List.of("--release", String.valueOf(RELEASE), "-Xlint:all",
                        "-d", out.toString(), "-proc:none");
                boolean compiled = compiler.getTask(null, fm, diags, options, null,
                        fm.getJavaFileObjectsFromPaths(sources)).call();
                for (Diagnostic<? extends JavaFileObject> d : diags.getDiagnostics()) {
                    String file = d.getSource() == null ? null
                            : Path.of(d.getSource().toUri()).getFileName().toString();
                    r.diagnostics.add(new Diag(d.getKind().name(), file, d.getLineNumber(),
                            d.getMessage(Locale.ROOT)));
                }
                if (!compiled) {
                    r.ok = false;
                    r.error = "compilation failed";
                    return r;
                }
            }
            Path expectedFile = unit.resolve("expected.txt");
            if (Files.exists(expectedFile)) {
                r.expected = normalize(Files.readString(expectedFile));
                runMain(out, r);
                if (r.ok && !r.expected.equals(r.output)) {
                    r.ok = false;
                    r.error = "output differs from expected.txt";
                }
            }
        } catch (Exception e) {
            r.ok = false;
            r.error = e.toString();
        } finally {
            deleteTree(out);
        }
        return r;
    }

    static void runMain(Path classes, Result r) throws Exception {
        ByteArrayOutputStream buf = new ByteArrayOutputStream();
        PrintStream saved = System.out;
        PrintStream savedErr = System.err;
        PrintStream capture = new PrintStream(buf, true, StandardCharsets.UTF_8);
        Throwable[] failure = new Throwable[1];
        try (URLClassLoader loader = new URLClassLoader(new URL[] {classes.toUri().toURL()},
                ClassLoader.getPlatformClassLoader())) {
            System.setOut(capture);
            System.setErr(capture);
            Thread t = new Thread(() -> {
                try {
                    Class<?> main = Class.forName("Main", true, loader);
                    Method m = main.getDeclaredMethod("main", String[].class);
                    m.setAccessible(true);
                    m.invoke(null, (Object) new String[0]);
                } catch (InvocationTargetException e) {
                    failure[0] = e.getCause();
                } catch (Throwable e) {
                    failure[0] = e;
                }
            }, "kata-main");
            t.setDaemon(true);
            t.start();
            t.join(RUN_TIMEOUT_MS);
            if (t.isAlive()) {
                r.ok = false;
                r.error = "timed out after " + RUN_TIMEOUT_MS + " ms";
            }
        } finally {
            System.setOut(saved);
            System.setErr(savedErr);
        }
        capture.flush();
        r.output = normalize(buf.toString(StandardCharsets.UTF_8));
        if (failure[0] != null) {
            r.ok = false;
            r.error = "Main.main threw " + failure[0];
        }
    }

    /** Strips trailing whitespace from every line and trailing blank lines. */
    static String normalize(String s) {
        String[] lines = s.replace("\r\n", "\n").split("\n", -1);
        StringBuilder b = new StringBuilder();
        for (String line : lines) b.append(line.stripTrailing()).append('\n');
        return b.toString().stripTrailing();
    }

    static String q(String s) {
        StringBuilder b = new StringBuilder("\"");
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            switch (c) {
                case '"' -> b.append("\\\"");
                case '\\' -> b.append("\\\\");
                case '\n' -> b.append("\\n");
                case '\r' -> b.append("\\r");
                case '\t' -> b.append("\\t");
                default -> {
                    if (c < 0x20) b.append(String.format("\\u%04x", (int) c));
                    else b.append(c);
                }
            }
        }
        return b.append('"').toString();
    }

    static void deleteTree(Path p) {
        try (Stream<Path> s = Files.walk(p)) {
            s.sorted(Comparator.reverseOrder()).forEach(x -> x.toFile().delete());
        } catch (IOException ignored) {
        }
    }
}
