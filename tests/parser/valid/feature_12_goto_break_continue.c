/* ============================================================================
 * FEATURE 12: goto, break, continue   (Basic Features)
 *
 * SYNTAX CHECKS        Backward `goto`, forward `goto`, labelled statements,
 *                      `break` in a loop and in a switch, and `continue` in a
 *                      loop.
 * LABELLING CHECKS     THE POINT OF THIS TEST — a label identifier is
 *                      labelled LABEL both at its definition site
 *                      (`retry:`) and at the `goto` that references it, and
 *                      this works for forward references too, where the label
 *                      has not yet been seen when the `goto` is reduced.
 * NOT A SYNTAX CONCERN Whether a label is ever defined, ever used, or
 *                      duplicated. A `goto missing;` with no `missing:` label
 *                      anywhere still parses and still labels as LABEL — the
 *                      symbol table is not consulted to resolve it. Also not
 *                      checked: jumping into a block, jumping over an
 *                      initialization, unreachable code after a jump, and
 *                      whether a `break`/`continue` actually sits inside an
 *                      enclosing loop or switch.
 * ==========================================================================*/
int main() {
    int i = 0;
    int n = 0;

    /* backward goto */
retry:
    i++;
    if (i < 3) { goto retry; }

    /* forward goto — the label is not yet known at this point */
    goto finish;

    n = 999;          /* skipped at runtime; still parsed */

finish:
    n = 1;

    /* break and continue inside a loop */
    for (i = 0; i < 10; i++) {
        if (i == 0) { continue; }
        if (i == 5) { break; }
        n = n + i;
    }

    /* break inside a switch */
    switch (n) {
        case 1:  n = 10; break;
        default: n = 20; break;
    }

    return n;
}
