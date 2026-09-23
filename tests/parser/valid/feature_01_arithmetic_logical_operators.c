/* ============================================================================
 * FEATURE 01: All arithmetic and logical operators   (Basic Features)
 *
 * SYNTAX CHECKS        Full precedence chain parses: arithmetic, relational,
 *                      logical, bitwise, shifts, ternary, unary, and every
 *                      compound-assignment operator.
 * LABELLING CHECKS     Every operand is an INT_VARIABLE in scope `main`;
 *                      operators themselves carry Token_Type == Token_Name.
 * NOT A SYNTAX CONCERN Operator *semantics* are invisible here: no constant
 *                      folding, no division-by-zero detection, no overflow,
 *                      no operand type-compatibility check. `a / 0` and
 *                      `1.5 & 2` both parse cleanly — rejecting them needs
 *                      type checking, which is a later stage.
 * ==========================================================================*/
int main() {
    int a = 12;
    int b = 5;

    /* arithmetic */
    int sum  = a + b;
    int diff = a - b;
    int prod = a * b;
    int quot = a / b;
    int rem  = a % b;

    /* unary */
    int neg  = -a;
    int pos  = +b;
    int lnot = !a;
    int bnot = ~a;

    /* relational */
    int lt = a <  b;
    int gt = a >  b;
    int le = a <= b;
    int ge = a >= b;
    int eq = a == b;
    int ne = a != b;

    /* logical */
    int land = (a > 0) && (b > 0);
    int lor  = (a > 0) || (b > 0);

    /* bitwise and shifts */
    int band = a & b;
    int bor  = a | b;
    int bxor = a ^ b;
    int shl  = a << 2;
    int shr  = a >> 1;

    /* ternary, including right-associative nesting */
    int max  = (a > b) ? a : b;
    int sign = (a > 0) ? 1 : (a < 0) ? -1 : 0;

    /* compound assignment — all eleven forms */
    a += 1; a -= 1; a *= 2; a /= 2; a %= 7;
    a &= 15; a |= 1; a ^= 3; a <<= 1; a >>= 1;

    /* increment / decrement, prefix and postfix */
    a++; ++a; a--; --a;

    /* precedence: * binds tighter than +, && tighter than || */
    int prec = a + b * 2 - a / b;
    int logic = a > 0 && b > 0 || a == b;

    return prec + logic + max + sign;
}
