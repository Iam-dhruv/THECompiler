/* TYPE CHECK — a reference must be initialized, from an lvalue of the same
 * type; a reference parameter needs an lvalue argument. */
void bump(int &n) { n = n + 1; }
int main() {
    int x = 1;
    float f = 2.0;
    int &r1 = x + 1;
    int &r2 = f;
    bump(5);
    bump(f);
    int &r3;
    return x;
}
