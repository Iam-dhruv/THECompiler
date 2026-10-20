/* TYPE CHECK — a function pointer accepts only a function (or another
 * pointer) of exactly its signature, and is called with that many arguments. */
int add(int a, int b) { return a + b; }
int neg(int a) { return -a; }
int main() {
    int (*op)(int, int) = add;
    int (*one)(int) = neg;
    op = neg;
    op = one;
    return op(1);
}
