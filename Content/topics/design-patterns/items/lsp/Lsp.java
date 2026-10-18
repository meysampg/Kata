// [[before
class Rect {
    protected int w, h;
    Rect(int w, int h) { this.w = w; this.h = h; }
    void setW(int w) { this.w = w; }
    void setH(int h) { this.h = h; }
    int area() { return w * h; }
}

final class SquareBefore extends Rect {      // mathematically "is a" Rect
    SquareBefore(int side) { super(side, side); }
    @Override void setW(int w) { this.w = w; this.h = w; }
    @Override void setH(int h) { this.w = h; this.h = h; }
}
// ]]

// [[after
sealed interface Shape permits Rectangle, Square {
    int area();
}

record Rectangle(int w, int h) implements Shape {
    public int area() { return w * h; }
    Rectangle withW(int w) { return new Rectangle(w, h); }
}

record Square(int side) implements Shape {
    public int area() { return side * side; }
    Square withSide(int side) { return new Square(side); }
}
// ]]

class Main {
    // [[client
    static int stretch(Rect r) {
        r.setW(5);
        r.setH(2);
        return r.area();                     // contract: 5 * 2
    }
    // ]]

    public static void main(String[] args) {
        System.out.println("Rect: " + stretch(new Rect(1, 1)));
        System.out.println("Square: " + stretch(new SquareBefore(1)));

        Shape[] shapes = { new Rectangle(5, 2), new Square(3) };
        int total = 0;
        for (Shape s : shapes) total += s.area();
        System.out.println("total area: " + total);
        System.out.println(new Rectangle(1, 1).withW(5).area());
    }
}
