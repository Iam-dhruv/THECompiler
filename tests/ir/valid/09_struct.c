/* FEATURE 09 — structures.
 * Each struct gets a layout (.types): members in order, each aligned to its
 * own alignment, size rounded up to the largest. s.f is the object at f's
 * byte offset inside s (s[off]); p->f adds the offset to p and dereferences;
 * nested members add their offsets. Structs pass by value. */
struct Point { int x; int y; };
struct Rect { char tag; struct Point corner; double area; };
int sum(struct Point p) {
    return p.x + p.y;
}
int main() {
    struct Point pt = {3, 4};
    struct Rect box;
    struct Point *pp = &pt;
    pp->y = 6;
    box.corner.x = pt.x;
    box.area = 2;
    return sum(pt) + box.corner.y;
}
