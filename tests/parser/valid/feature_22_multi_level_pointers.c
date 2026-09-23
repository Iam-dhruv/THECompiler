/* ============================================================================
 * FEATURE 22: Multi-level pointers   (Advanced Features)
 *
 * SYNTAX CHECKS        Pointer declarators nest to any depth (`*`, `**`,
 *                      `***`, `****`), as do the matching dereference chains
 *                      and address-of chains.
 * LABELLING CHECKS     DISPLAY DEFECT, deliberately pinned by this test.
 *                      pointer_depth is STORED correctly for every depth, but
 *                      format_semantic_type() saturates the rendering at two:
 *                        p    (depth 1) -> INT_POINTER            correct
 *                        pp   (depth 2) -> INT_POINTER_POINTER    correct
 *                        ppp  (depth 3) -> INT_POINTER_POINTER    SATURATED
 *                        pppp (depth 4) -> INT_POINTER_POINTER    SATURATED
 *                      So `int**` and `int****` are indistinguishable in the
 *                      output even though the underlying data differs. This is
 *                      a rendering bug only — one extra branch in
 *                      format_semantic_type() would fix it. See
 *                      FEATURE_PROGRESS.md, Advanced -> Multi-level pointers.
 * NOT A SYNTAX CONCERN Whether a dereference chain matches the declared depth.
 *                      `***p` on a single-level `int *p` would parse — arity
 *                      of dereference against pointer depth is type checking.
 * ==========================================================================*/
int main() {
    int     target = 42;
    int    *p;
    int   **pp;
    int  ***ppp;
    int ****pppp;

    p    = &target;
    pp   = &p;
    ppp  = &pp;
    pppp = &ppp;

    /* dereference chains of each depth */
    *p          = 1;
    **pp        = 2;
    ***ppp      = 3;
    ****pppp    = 4;

    int read_one  = *p;
    int read_four = ****pppp;

    /* char pointers at depth for contrast */
    char   letter = 'a';
    char  *cp     = &letter;
    char **cpp    = &cp;
    **cpp = 'b';

    return read_one + read_four;
}
