/* ============================================================================
 * FEATURE 05: do-while loop   (Basic Features)
 *
 * SYNTAX CHECKS        `do <stmt> while (expr);` with braced and unbraced
 *                      bodies, nesting, and the mandatory trailing semicolon.
 * LABELLING CHECKS     `d`, `k` are INT_VARIABLE in `main`; a declaration
 *                      inside the braced body gets a nested `main.blockN`.
 * NOT A SYNTAX CONCERN The defining behaviour of do-while — that the body runs
 *                      at least once before the condition is tested — is
 *                      execution semantics. The parser only records the shape;
 *                      nothing here distinguishes it from `while` at runtime.
 * ==========================================================================*/
int main() {
    int d = 0;
    int k = 0;

    do {
        d++;
    } while (d < 3);

    /* unbraced body */
    do
        d++;
    while (d < 6);

    /* body runs even though the condition is false from the start */
    do { k = 1; } while (0);

    /* nested */
    d = 0;
    do {
        k = 0;
        do {
            k++;
        } while (k < 2);
        d++;
    } while (d < 2);

    return d + k;
}
