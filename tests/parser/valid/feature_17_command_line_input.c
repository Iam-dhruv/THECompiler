/* ============================================================================
 * FEATURE 17: Command line input   (Advanced Features)
 *
 * SYNTAX CHECKS        The canonical `int main(int argc, char *argv[])`
 *                      signature parses, as does indexing argv and passing it
 *                      onward to another function.
 * LABELLING CHECKS     argc -> INT_PARAMETER                    (correct)
 *                      argv -> CHAR_ARRAY_PARAMETER             (DEFECT)
 *                      KNOWN DEFECT, deliberately pinned: `char *argv[]` is a
 *                      pointer AND an array, but format_semantic_type() tests
 *                      is_array before pointer_depth, so the pointer is
 *                      dropped and `char *x[]` can never render as a pointer.
 *                      A faithful label would be CHAR_POINTER_ARRAY_PARAMETER.
 *                      Same defect on `list` in `show`. See
 *                      FEATURE_PROGRESS.md, Advanced -> Command line input.
 * NOT A SYNTAX CONCERN That argc and argv must agree with each other, that
 *                      argv is NULL-terminated, or that argv[i] is in range.
 *                      Reading argv[99] below parses fine. These are runtime
 *                      contracts, not grammar.
 * ==========================================================================*/
void show(int n, char *list[]);

void show(int n, char *list[]) {
    int i;
    for (i = 0; i < n; i++) {
        printf("%s\n", list[i]);
    }
}

int main(int argc, char *argv[]) {
    printf("argc = %d\n", argc);
    printf("%s\n", argv[0]);

    if (argc > 1) {
        printf("%s\n", argv[1]);
    }

    /* out of range: not a parsing concern */
    printf("%s\n", argv[99]);

    show(argc, argv);
    return 0;
}
