/* FEATURE 16 — function pointers.
 * int (*op)(int, int) is a pointer to a function of that signature.
 * Assigning a function stores its address (&add@ii, an address constant);
 * with overloads, the one matching the pointer's signature is chosen. A call
 * through the pointer — op(a, b) or (*op)(a, b) — is indirect:
 * "t = icall op, n". Function pointers can be passed as arguments. */
int add(int a, int b) { return a + b; }
float add(float a, float b) { return a + b; }
int mul(int a, int b) { return a * b; }
int apply(int (*f)(int, int), int x) {
    return f(x, x);
}
int main() {
    int (*op)(int, int);
    op = add;
    int r = op(2, 3);
    op = mul;
    r = r + (*op)(4, 5);
    r = r + apply(mul, 6);
    return r;
}
