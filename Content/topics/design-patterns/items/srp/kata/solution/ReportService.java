import java.util.List;
import java.util.Objects;

final class ReportService {
    private final InvoiceParser parser;
    private final InvoiceFormatter formatter;
    private final Sender sender;

    ReportService(InvoiceParser parser, InvoiceFormatter formatter,
                  Sender sender) {
        this.parser = Objects.requireNonNull(parser, "parser");
        this.formatter = Objects.requireNonNull(formatter, "formatter");
        this.sender = Objects.requireNonNull(sender, "sender");
    }

    String run(String csv) {
        String text = formatter.format(parser.parse(csv));
        sender.send(text);
        return text;
    }
}

final class Reports {
    private Reports() { }

    static String run(String csv, List<String> outbox) {
        return new ReportService(new InvoiceParser(), new InvoiceFormatter(),
            outbox::add).run(csv);
    }
}
