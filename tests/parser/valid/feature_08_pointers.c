/* ============================================================================
 * FEATURE 08: Pointers   (Basic Features)
 *
 * SYNTAX CHECKS        Pointer declarations, address-of, dereference on both
 *                      sides of an assignment, pointer arithmetic, pointer
 *                      comparison, and a pointer parameter.
 * LABELLING CHECKS     THE POINT OF THIS TEST — the declared identifier must
 *                      carry the right Token_Type:
 *                        p, q     -> INT_POINTER
 *                        cp       -> CHAR_POINTER
 *                        target   -> INT_VARIABLE
 *                        out      -> INT_POINTER_PARAMETER  (in scope `store`)
 *                      As with arrays, the modifier replaces _VARIABLE:
 *                      a pointer variable is INT_POINTER, not
 *                      INT_POINTER_VARIABLE. A parameter always keeps the
 *                      explicit _PARAMETER suffix.
 * NOT A SYNTAX CONCERN Everything that makes pointers dangerous: null-ness,
 *                      dangling pointers, whether a dereference is valid,
 *                      aliasing, and pointer/integer type mismatches. `*p`
 *                      where p was never assigned parses fine. These need
 *                      type checking and flow analysis — later stages.
 * ==========================================================================*/
void store(int *out, int value);

void store(int *out, int value) {
    *out = value;
}

int main() {
    int   target = 42;
    int  *p;
    int  *q;
    char  letter = 'x';
    char *cp;

    p  = &target;      /* address-of */
    *p = 43;           /* dereference as assignment target   */
    int copy = *p;     /* dereference as rvalue              */
    cp = &letter;

    /* pointer arithmetic and comparison */
    q = p + 1;
    q = q - 1;
    int same = (p == q);
    int diff = (p != q);

    store(&target, 99);

    return copy + same + diff;
}
