/* ============================================================================
 * FEATURE 02: if-else   (Basic Features)
 *
 * SYNTAX CHECKS        Plain `if`, `if/else`, `else if` chains, unbraced
 *                      bodies, and nested forms. Dangling `else` binds to the
 *                      nearest unmatched `if` via the %nonassoc IFX / T_ELSE
 *                      precedence pair in parser.y.
 * LABELLING CHECKS     A braced body opens a nested block scope, so `inner`
 *                      is labelled INT_VARIABLE in scope `main.blockN`, while
 *                      `a`/`b`/`r` stay in `main`.
 * NOT A SYNTAX CONCERN Condition truthiness and type: `if (3.7)` and
 *                      `if (ptr)` parse identically to `if (a > b)`. Whether a
 *                      condition is boolean-like, and whether a branch is
 *                      reachable or exhaustive, are not syntax questions.
 * ==========================================================================*/
int main() {
    int a = 1;
    int b = 2;
    int r = 0;

    if (a > b) { r = 1; }

    if (a > b) { r = 1; } else { r = 2; }

    if (a > b)      { r = 3; }
    else if (a < b) { r = 4; }
    else            { r = 5; }

    /* unbraced bodies: else binds to the INNER if */
    if (a > 0)
        if (b > 0)
            r = 6;
        else
            r = 7;

    /* a braced body introduces its own scope */
    if (a == 1) {
        int inner = 9;
        r = inner;
    }

    return r;
}
