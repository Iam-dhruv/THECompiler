/* ============================================================================
 * FEATURE 04: while loop   (Basic Features)
 *
 * SYNTAX CHECKS        Braced and unbraced bodies, an empty body, nested
 *                      loops, and `break`/`continue` inside the body.
 * LABELLING CHECKS     `w`, `n` are INT_VARIABLE in `main`; a variable
 *                      declared inside the braced body lands in a nested
 *                      `main.blockN` scope.
 * NOT A SYNTAX CONCERN Whether the loop ever terminates. `while (1) { }` is
 *                      syntactically flawless; proving termination is
 *                      undecidable in general and is no part of parsing.
 * ==========================================================================*/
int main() {
    int w = 3;
    int n = 0;

    while (w > 0) {
        w--;
    }

    /* unbraced body */
    w = 3;
    while (w > 0)
        w--;

    /* empty body */
    while (0) { }

    /* nested, with break and continue */
    w = 0;
    while (w < 3) {
        int guard = 1;
        n = 0;
        while (n < 3) {
            n++;
            if (n == 1) { continue; }
            if (n == 2) { break; }
        }
        w = w + guard;
    }

    return n;
}
