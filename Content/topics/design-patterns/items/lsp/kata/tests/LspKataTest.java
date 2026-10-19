import java.lang.reflect.Method;
import kata.*;

class LspKataTest {
    @Check(id = "rect-stretch")
    void rectStretch() {
        Expect.equal(20, Geometry.stretch(new Rect(2, 3)), "stretching a Rect to 5 by 4");
    }

    @Check(id = "square-area")
    void squareArea() {
        Expect.equal(9, new Square(3).area(), "a Square of side 3");
        Expect.equal(1, new Square(1).area(), "a Square of side 1");
    }

    @Check(id = "square-honours-rect-contract")
    void squareHonoursRectContract() throws Throwable {
        Class<?> rect = Types.named("Rect");
        Class<?> square = Types.named("Square");
        if (!rect.isAssignableFrom(square)) {
            return;   // not a Rect, so the Rect contract cannot be broken
        }
        Object s = Types.create(Types.constructor(square, int.class), 3);
        Types.call(Types.method(rect, "setW", int.class), s, 5);
        Types.call(Types.method(rect, "setH", int.class), s, 4);
        Object area = Types.call(Types.method(rect, "area"), s);
        Expect.equal(20, area, "a Square used as a Rect, after setW(5) and setH(4)");
    }

    @Check(id = "shape-interface", kind = Kind.DESIGN)
    void shapeInterface() {
        Class<?> shape = Types.named("Shape");
        Expect.isTrue(shape.isInterface(), "Shape should be an interface");
        Method m = Types.singleAbstractMethod(shape);
        Expect.equal("area", m.getName(), "the method name");
        Expect.equal(int.class, m.getReturnType(), "area's return type");
    }

    @Check(id = "both-are-shapes", kind = Kind.DESIGN)
    void bothAreShapes() {
        Class<?> shape = Types.named("Shape");
        Expect.isTrue(shape.isAssignableFrom(Types.named("Rect")), "Rect should be a Shape");
        Expect.isTrue(shape.isAssignableFrom(Types.named("Square")), "Square should be a Shape");
    }
}
