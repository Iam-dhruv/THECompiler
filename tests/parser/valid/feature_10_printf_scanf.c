/* ============================================================================
 * FEATURE 10: printf and scanf   (Basic Features)
 *
 * SYNTAX CHECKS        Calls with a varying number of arguments parse, because
 *                      argument_expr_list is unbounded. Covers zero extra
 *                      args, several args, mixed argument types, and `&x` as
 *                      a scanf argument.
 * LABELLING CHECKS     printf / scanf -> FUNCTION_CALL(returns:UNKNOWN).
 *                      That is the CORRECT label here: with no preprocessor
 *                      there is no <stdio.h>, so these are genuinely
 *                      undeclared functions and their return type is unknown.
 * NOT A SYNTAX CONCERN Format strings entirely. `printf("%q\n", n)`,
 *                      `printf("%d %d\n", n)` (too few args) and
 *                      `printf("%s\n", n)` (wrong type) all parse. Per C11
 *                      7.21.6.1p9 an invalid conversion specification is
 *                      UNDEFINED BEHAVIOUR AT RUNTIME, not a translation-time
 *                      error — the C standard does not require a compiler to
 *                      diagnose it. GCC's -Wformat is a non-standard extension
 *                      driven by __attribute__((format(printf,...))) and only
 *                      warns. Checking it would need call-site type info (a
 *                      type-checking concern) and cannot live in the lexer,
 *                      since a string literal is not necessarily a format
 *                      string: `char *s = "100%q";` is perfectly legal.
 *                      Variadic *prototypes* (`...`) are excluded by the spec.
 * ==========================================================================*/
int main() {
    int   n = 5;
    float f = 1.5;
    char  c = 'x';

    /* no extra arguments */
    printf("hello\n");

    /* one and several arguments, mixed types */
    printf("%d\n", n);
    printf("%d %f %c\n", n, f, c);
    printf("%s and %d\n", "text", n);

    /* an expression as an argument */
    printf("%d\n", n * 2 + 1);

    /* scanf with address-of arguments */
    scanf("%d", &n);
    scanf("%d %f", &n, &f);

    return n;
}
