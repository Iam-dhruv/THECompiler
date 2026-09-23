/* ============================================================================
 * FEATURE 19: Reference   (Advanced Features)
 *
 * SYNTAX CHECKS        `int &r = x;` parses, as does a reference parameter
 *                      `void bump(int &n)`, and a reference to a struct.
 * LABELLING CHECKS     KNOWN DEFECT, deliberately pinned by this test.
 *                      parser.y's declarator rule `T_BIT_AND direct_declarator`
 *                      DISCARDS the `&`, so a reference is labelled exactly
 *                      like a value:
 *                        ref     -> INT_VARIABLE        (not INT_REFERENCE)
 *                        n       -> INT_PARAMETER       (not INT_REFERENCE_PARAMETER)
 *                        alias   -> STRUCT_VARIABLE
 *                      There is no reference bit in TypeInfo, so aliasing is
 *                      invisible to every later phase. See
 *                      FEATURE_PROGRESS.md, Advanced -> Reference.
 * NOT A SYNTAX CONCERN The rules that make references safe: that a reference
 *                      MUST be initialized at declaration, cannot be reseated,
 *                      and cannot be null. `int &loose;` (uninitialized) would
 *                      parse here. Enforcing initialization is a semantic
 *                      check, not a grammar one.
 * ==========================================================================*/
struct Point { int x; int y; };

void bump(int &n);

void bump(int &n) {
    n = n + 1;
}

int main() {
    int value = 10;
    int &ref  = value;      /* reference binds to value */

    ref = 20;               /* writes through the alias */
    value = value + ref;

    struct Point origin;
    struct Point &alias = origin;
    alias.x = 1;

    bump(value);            /* pass by reference */

    return value;
}
