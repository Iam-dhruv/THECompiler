/* ============================================================================
 * FEATURE 21: until loop   (Advanced Features)
 *
 * SYNTAX CHECKS        This language's own non-C extension, in BOTH supported
 *                      forms:
 *                        do { ... } until (cond);     post-tested
 *                        until (cond) { ... }         pre-tested
 *                      Braced and unbraced bodies, nesting, and break/continue
 *                      inside an until body all parse.
 * LABELLING CHECKS     `u`, `n` are INT_VARIABLE in `main`; a declaration
 *                      inside a braced until body gets a nested `main.blockN`
 *                      scope, exactly like any other loop body.
 * NOT A SYNTAX CONCERN The inverted-condition SEMANTICS — that `until (c)`
 *                      loops while c is false, the opposite of `while` — is
 *                      pure runtime behaviour. Nothing in the parse output
 *                      distinguishes it from `while`; the two produce the same
 *                      shape of token table. Termination is likewise not
 *                      analysed.
 * ==========================================================================*/
int main() {
    int u = 0;
    int n = 0;

    /* post-tested form: body runs at least once */
    do {
        u++;
    } until (u >= 3);

    /* unbraced post-tested body */
    do
        u++;
    while (u < 5);

    /* pre-tested form */
    until (u >= 8) {
        u++;
    }

    /* unbraced pre-tested body */
    until (u >= 10)
        u++;

    /* nested, with break and continue */
    u = 0;
    until (u >= 3) {
        int guard = 1;
        n = 0;
        until (n >= 3) {
            n++;
            if (n == 1) { continue; }
            if (n == 2) { break; }
        }
        u = u + guard;
    }

    return u + n;
}
