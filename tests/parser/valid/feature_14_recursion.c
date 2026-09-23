/* ============================================================================
 * FEATURE 14: Recursive function call   (Advanced Features)
 *
 * SYNTAX CHECKS        Direct self-recursion, mutual recursion resolved
 *                      through forward prototypes, and recursion in a
 *                      non-tail position.
 * LABELLING CHECKS     THE POINT OF THIS TEST — a self-call inside the
 *                      function's own body resolves correctly:
 *                        `factorial` inside factorial's body
 *                            -> FUNCTION_CALL(returns:INT), scope `factorial`
 *                      This works because the function is inserted into the
 *                      GLOBAL scope before its body is parsed. Mutual
 *                      recursion works the same way via the prototypes:
 *                        `is_odd` inside is_even -> FUNCTION_CALL(returns:INT)
 * NOT A SYNTAX CONCERN Termination and stack depth. A function that calls
 *                      itself unconditionally, like `spin` below, is
 *                      syntactically valid and will recurse forever at
 *                      runtime. Detecting non-termination is undecidable;
 *                      detecting probable stack overflow is not a parsing job.
 * ==========================================================================*/
int factorial(int n);
int is_even(int n);
int is_odd(int n);
int spin(int n);

int factorial(int n) {
    if (n <= 1) { return 1; }
    return n * factorial(n - 1);       /* recursion in a non-tail position */
}

int is_even(int n) {
    if (n == 0) { return 1; }
    return is_odd(n - 1);              /* mutual recursion */
}

int is_odd(int n) {
    if (n == 0) { return 0; }
    return is_even(n - 1);
}

/* unconditional self-call: well-formed syntax, non-terminating at runtime */
int spin(int n) {
    return spin(n);
}

int main() {
    int f = factorial(5);
    int e = is_even(4);
    return f + e;
}
