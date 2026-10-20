/* FEATURE 02 — if and if-else, nested, with a dangling else.
 * if (B) M1 S1 N else M2 S2: B.true -> M1, B.false -> M2, and the goto
 * emitted at N jumps over S2. The else binds to the nearest if. */
int main() {
    int a = 5;
    int r = 0;
    if (a > 3)
        r = 1;
    else
        r = 2;
    if (a == 5)
        if (r != 0) r = 3;
        else r = 4;
    if (a < 0) {
        r = -1;
    }
    return r;
}
