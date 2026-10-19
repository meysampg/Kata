interface Shape {
    int area();
}

class Rect implements Shape {
    protected int w, h;

    Rect(int w, int h) { this.w = w; this.h = h; }

    void setW(int w) { this.w = w; }
    void setH(int h) { this.h = h; }
    public int area() { return w * h; }
}

final class Square implements Shape {
    private int side;

    Square(int side) { this.side = side; }

    void setSide(int side) { this.side = side; }
    public int area() { return side * side; }
}

final class Geometry {
    private Geometry() { }

    static int stretch(Rect r) {
        r.setW(5);
        r.setH(4);
        return r.area();
    }
}
