/* FEATURE 14 — recursive function calls.
 * A function enters the symbol table (under its mangled name) before its
 * body is parsed, so it can call itself; a prototype allows mutual
 * recursion. */
int is_odd(int n);
int factorial(int n) {
    if (n <= 1) return 1;
    return n * factorial(n - 1);
}
int is_even(int n) {
    if (n == 0) return 1;
    return is_odd(n - 1);
}
int is_odd(int n) {
    if (n == 0) return 0;
    return is_even(n - 1);
}
int main() {
    return factorial(5) + is_even(4);
}
