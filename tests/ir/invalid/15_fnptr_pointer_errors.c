/* TYPE CHECK — a pointer to a function pointer is a data pointer: it cannot
 * be called, and it converts only to/from the same pointer-to-function-pointer
 * type, never to a function pointer or a function. */
int add(int a, int b) { return a + b; }
int main() {
    int (*op)(int, int) = add;
    int (**pp)(int, int) = &op;
    int (**pf)(float, float);
    int r = pp(1, 2);
    pp = add;
    pp = op;
    op = pp;
    pf = pp;
    return r;
}
