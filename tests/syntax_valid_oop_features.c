struct Point {
    int x;
    int y;
};

enum Color {
    RED,
    GREEN,
    BLUE
};

typedef int Integer;

class Shape {
    public:
    int area;

    int getArea() {
        return this->area;
    }

    private:
    int hidden;
};

int main() {
    struct Point p;
    p.x = 1;
    p.y = 2;

    enum Color c;
    c = RED;

    class Shape s;
    s.area = 10;

    int *dyn;
    dyn = new int;
    delete dyn;

    return 0;
}
