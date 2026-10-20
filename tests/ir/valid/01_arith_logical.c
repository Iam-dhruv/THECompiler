/* FEATURE 01 — arithmetic and logical operators.
 * Arithmetic, bitwise and shift operators, unary - and ~, compound
 * assignment, ++/--. Operands are evaluated left to right; a subexpression
 * made only of constants is folded at compile time. */
int main() {
    int a = 7;
    int b = 3;
    int c;
    c = a + b * 2;
    c = (a - b) / 2 % 3;
    c = a << 2 | b & 1 ^ 5;
    c = -a + ~b;
    c += a;
    c <<= 1;
    a++;
    --b;
    c = 2 * 3 + 4;
    c = a > 0 && b < 5;
    c = !(a == b) || c != 0;
    return c;
}
