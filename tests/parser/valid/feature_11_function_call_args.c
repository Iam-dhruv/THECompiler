/* ============================================================================
 * FEATURE 11: Function call with arguments   (Basic Features)
 *
 * SYNTAX CHECKS        Prototypes, definitions, calls with zero/one/many
 *                      arguments, expression arguments, nested calls, a call
 *                      used as a subexpression, and a void function.
 * LABELLING CHECKS     THE POINT OF THIS TEST — the same name takes three
 *                      different roles depending on context:
 *                        at the prototype  -> FUNCTION_PROTOTYPE(returns:INT)
 *                        at the definition -> FUNCTION_DEFINITION(returns:INT)
 *                        at a call site    -> FUNCTION_CALL(returns:INT)
 *                      Return type is carried through: `greet` is
 *                      FUNCTION_*(returns:VOID). Parameters are labelled in
 *                      the function's own scope: `a`/`b` are INT_PARAMETER in
 *                      scope `add`.
 * NOT A SYNTAX CONCERN Argument count and argument types are NOT checked
 *                      against the declaration. `add(1)`, `add(1,2,3)` and
 *                      `add("x", 'y')` would all parse — arity and type
 *                      agreement is classic type checking, a later stage.
 *                      Nor is a missing return value on a non-void function
 *                      detected.
 * ==========================================================================*/
int  add(int a, int b);
int  square(int n);
void greet();

int add(int a, int b)  { return a + b; }
int square(int n)      { return n * n; }
void greet()           { printf("hi\n"); }

int main() {
    int x = 3;
    int y = 4;

    int s1 = add(x, y);              /* simple call            */
    int s2 = add(1, 2);              /* literal arguments      */
    int s3 = add(x + 1, y * 2);      /* expression arguments   */
    int s4 = add(square(x), y);      /* nested call            */
    int s5 = add(add(1, 2), 3);      /* call inside a call     */

    greet();                         /* void call, no args     */

    /* call used directly as a subexpression */
    int total = add(x, y) * 2 + square(y);

    return s1 + s2 + s3 + s4 + s5 + total;
}
