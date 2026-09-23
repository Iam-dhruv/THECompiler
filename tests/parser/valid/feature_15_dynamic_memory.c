/* ============================================================================
 * FEATURE 15: Dynamic memory allocation   (Advanced Features)
 *
 * SYNTAX CHECKS        `new T`, `new T[n]` with a constant and with an
 *                      expression size, `delete p`, and `delete[] arr` are
 *                      dedicated grammar productions. malloc/free also parse,
 *                      as ordinary undeclared calls.
 * LABELLING CHECKS     The receiving variable carries the pointer modifier:
 *                        one, many, block -> INT_POINTER
 *                        text             -> CHAR_POINTER
 *                      malloc/free -> FUNCTION_CALL(returns:UNKNOWN), correct
 *                      because with no preprocessor they are undeclared.
 * NOT A SYNTAX CONCERN All memory correctness: leaks (allocating without
 *                      freeing), double frees, use-after-free, and mismatched
 *                      `delete` vs `delete[]`. The deliberate leak and double
 *                      delete below both parse cleanly. The allocation SIZE is
 *                      not even recorded in TypeInfo, so no later phase could
 *                      currently check it either. These need flow analysis,
 *                      well beyond syntax.
 * ==========================================================================*/
int main() {
    int count = 10;

    int  *one  = new int;
    int  *many = new int[100];
    int  *expr = new int[count * 2];   /* expression as the size */
    char *text = new char[32];

    *one = 5;
    many[0] = 1;
    text[0] = 'a';

    delete one;
    delete [] many;
    delete [] text;

    /* mismatched form: not diagnosed at this stage */
    int *block = new int[4];
    delete block;

    /* deliberate leak: allocated, never deleted */
    int *leaked = new int[8];
    leaked[0] = 1;

    /* C-style allocation, as undeclared calls */
    int *raw = malloc(40);
    free(raw);
    free(raw);                         /* double free: not diagnosed */

    return *expr;
}
