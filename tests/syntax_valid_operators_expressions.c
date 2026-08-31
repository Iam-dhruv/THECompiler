/* ============================================================================
 * syntax_valid_operators_expressions.c
 * Validates ALL Arithmetic, Relational, Logical, Bitwise, Assignment, and Ternary
 * operators with layered operator precedence and associativity.
 * ==========================================================================*/

int test_operators(int a, int b) {
    int result = 0;
    int x = 10;
    int y = 20;

    /* Arithmetic Operators (+, -, *, /, %, unary +, unary -) */
    result = a + b - 5 * (a / (b + 1)) % 3;
    result = +x - -y;

    /* Increment and Decrement (prefix & postfix) */
    x++;
    x--;
    ++x;
    --x;
    result = ++x + y-- * --x;

    /* Relational Operators (<, >, <=, >=, ==, !=) */
    result = (a < b) + (a > b) + (a <= b) + (a >= b) + (a == b) + (a != b);

    /* Logical Operators (&&, ||, !) */
    result = (a > 0 && b > 0) || !(a == b);

    /* Bitwise Operators (&, |, ^, ~, <<, >>) */
    result = (a & b) | (a ^ b) & ~b;
    result = (a << 2) >> 1;

    /* Ternary Conditional Operator (? :) */
    result = (a > b) ? (a + 1) : (b - 1);
    result = (a == 0) ? 0 : (a > 0 ? 1 : -1);

    /* All Compound Assignment Operators */
    result = a;
    result += b;
    result -= 2;
    result *= 3;
    result /= 2;
    result %= 5;
    result &= 0xFF;
    result |= 0x10;
    result ^= 0x0F;
    result <<= 2;
    result >>= 1;

    return result;
}

int main() {
    int res = test_operators(40, 6);
    return res;
}
