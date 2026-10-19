import java.util.List;

final class Shop {
    private final OrderCommands commands = new OrderCommands();
    private final RevenueView view = new RevenueView();

    void place(String orderId, String customer, int cents) {
        commands.handle(new PlaceOrder(orderId, customer, cents));
        view.catchUp(commands.feed());
    }

    int revenue(String customer) { return view.revenue(customer); }

    List<String> top(int n) { return view.top(n); }
}
