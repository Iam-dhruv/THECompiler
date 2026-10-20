/* FEATURE 19 — references.
 * A reference is stored as a pointer: int &r = x emits r = &x, and every use
 * of r goes through it (t = *r, *r = v). A reference parameter makes each
 * call pass the argument's address, so the argument must be an lvalue; its
 * type code is R (bump@Ri). */
struct Point { int x; int y; };
void bump(int &n) {
    n = n + 1;
}
int main() {
    int value = 10;
    int &ref = value;
    ref = 20;
    value = value + ref;
    struct Point origin;
    struct Point &alias = origin;
    alias.y = 1;
    bump(value);
    bump(ref);
    return value;
}
