/* ============================================================================
 * FEATURE 16: Function pointer   (Advanced Features)
 *
 * SYNTAX CHECKS        `int (*fp)(int,int);` parses, via the parenthesized
 *                      declarator rule followed by a parameter list.
 *                      Assignment from a function name, and both call forms
 *                      `fp(a,b)` and `(*fp)(a,b)`, also parse.
 * LABELLING CHECKS     KNOWN DEFECT, deliberately pinned by this test.
 *                      `op` is labelled FUNCTION_PROTOTYPE(returns:INT) —
 *                      i.e. indistinguishable from an ordinary forward
 *                      declaration of a function called `op`. The "pointer
 *                      to" is entirely lost: there is no declarator form and
 *                      no TypeInfo bit for it, and declaring `op` even pushes
 *                      a scope named `op` as though a function body were
 *                      coming. At the call sites it then becomes
 *                      FUNCTION_CALL(returns:INT). parser.y's own header
 *                      comment states "No function-pointer declarators".
 *                      A correct label would be something like
 *                      INT_FUNCTION_POINTER. See FEATURE_PROGRESS.md.
 * NOT A SYNTAX CONCERN Whether the assigned function's signature matches the
 *                      pointer's declared signature. `op = wrong_shape;`
 *                      below assigns a one-parameter function to a
 *                      two-parameter pointer and is accepted — signature
 *                      compatibility is type checking.
 * ==========================================================================*/
int add(int a, int b);
int mul(int a, int b);
int wrong_shape(int a);

int add(int a, int b)   { return a + b; }
int mul(int a, int b)   { return a * b; }
int wrong_shape(int a)  { return a; }

int main() {
    int (*op)(int, int);

    op = add;
    int viaplain = op(2, 3);        /* call through the pointer     */
    int viaderef = (*op)(4, 5);     /* explicit dereference form    */

    op = mul;
    int second = op(6, 7);

    /* signature mismatch: accepted here, a type-checking concern */
    op = wrong_shape;

    return viaplain + viaderef + second;
}
