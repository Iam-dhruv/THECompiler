/* ============================================================================
 * FEATURE 13: static keyword   (Basic Features)
 *
 * SYNTAX CHECKS        `static` parses as a storage-class specifier on a
 *                      global variable, a local variable, and a function
 *                      definition, and combines with pointer and array
 *                      declarators.
 * LABELLING CHECKS     KNOWN DEFECT, deliberately pinned by this test:
 *                      `static` is parsed and then DISCARDED. TypeInfo has no
 *                      is_static field, so every identifier below is labelled
 *                      exactly as if `static` were absent:
 *                        counter      -> INT_VARIABLE   (not STATIC_*)
 *                        hidden       -> INT_VARIABLE
 *                        cache        -> INT_ARRAY
 *                      The `static` token itself does appear in the table as
 *                      T_STATIC, so the keyword is visible — but the storage
 *                      class never reaches the symbol table. See
 *                      FEATURE_PROGRESS.md, Basic Features -> `static`.
 * NOT A SYNTAX CONCERN What `static` actually MEANS: internal linkage at file
 *                      scope, and preserved-across-calls storage duration for
 *                      a local. Both are semantic/codegen properties; nothing
 *                      at parse time distinguishes a static local from an
 *                      ordinary one.
 * ==========================================================================*/
static int counter;
static int limit = 100;

static int bump(int by);

static int bump(int by) {
    static int hidden;      /* storage duration is a runtime notion */
    hidden = hidden + by;
    counter = counter + by;
    return hidden;
}

int main() {
    static int  cache[4];
    static int *slot;

    cache[0] = 1;
    slot = &cache[0];

    bump(1);
    bump(2);

    return counter + limit;
}
