/* Dangling-else resolution. With unbraced bodies the grammar is ambiguous
   unless `else` is made to bind to the NEAREST unmatched `if`; parser.y does
   this with the %nonassoc IFX / T_ELSE precedence pair. This file must parse
   with zero conflicts and zero errors. */
int main() {
    int a = 1;
    int b = 2;
    int r = 0;

    /* `else` binds to the INNER if */
    if (a > 0)
        if (b > 0)
            r = 1;
        else
            r = 2;

    /* braces force the `else` onto the OUTER if */
    if (a > 0) {
        if (b > 0) { r = 3; }
    } else {
        r = 4;
    }

    /* else-if chain, unbraced */
    if (a > b)      r = 5;
    else if (a < b) r = 6;
    else            r = 7;

    /* deeply nested, mixed braced and unbraced */
    if (a)
        if (b)
            if (a == b) r = 8;
            else        r = 9;
        else r = 10;
    else r = 11;

    return r;
}
