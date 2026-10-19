class Rect {
    protected int w, h;

    Rect(int w, int h) { this.w = w; this.h = h; }

    void setW(int w) { this.w = w; }
    void setH(int h) { this.h = h; }
    int area() { return w * h; }
}

// "A square is a rectangle", mathematically.
final class Square extends Rect {
    Square(int side) { super(side, side); }

    @Override void setW(int w) { this.w = w; this.h = w; }
    @Override void setH(int h) { this.w = h; this.h = h; }
}

final class Geometry {
    private Geometry() { }

    // Written against Rect's contract: width and height change independently.
    static int stretch(Rect r) {
        r.setW(5);
        r.setH(4);
        return r.area();
    }
}
