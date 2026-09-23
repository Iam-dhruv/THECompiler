/* ============================================================================
 * FEATURE 03: for loop   (Basic Features)
 *
 * SYNTAX CHECKS        Classic three-clause form, the infinite `for(;;)` form,
 *                      an empty increment clause, and a declaration used as
 *                      the init clause.
 * LABELLING CHECKS     `i` declared before the loop is INT_VARIABLE in `main`.
 *                      A loop whose init *declares* its counter and whose body
 *                      is braced puts that counter in the enclosing scope
 *                      (`main`), because the grammar's for-init declaration is
 *                      not given a scope of its own — the braced body is the
 *                      only thing that opens a block scope.
 * NOT A SYNTAX CONCERN Termination and trip count. `for (i = 0; i < 5; )` with
 *                      no increment is an infinite loop at runtime but is
 *                      perfectly well-formed syntax. Loop-bound analysis is
 *                      not a parsing concern at all.
 * ==========================================================================*/
int main() {
    int i;
    int total = 0;

    /* classic three-clause form */
    for (i = 0; i < 5; i++) {
        total = total + i;
    }

    /* declaration in the init clause */
    for (int j = 0; j < 3; j++) {
        total = total + j;
    }

    /* empty increment clause */
    for (i = 0; i < 2; ) {
        i++;
    }

    /* infinite form, exited with break */
    for (;;) {
        break;
    }

    /* unbraced body */
    for (i = 0; i < 4; i++)
        total = total + 1;

    return total;
}
