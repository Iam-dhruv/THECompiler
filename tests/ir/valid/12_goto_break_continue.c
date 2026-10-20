/* FEATURE 12 — goto, break and continue.
 * break/continue use a stack of loop/switch contexts whose jump lists are
 * patched when the construct closes; continue skips an enclosing switch and
 * targets the loop. A goto to a label not seen yet waits on a pending list
 * until the label is defined. */
int main() {
    int i = 0;
    int hits = 0;
    while (i < 10) {
        i = i + 1;
        switch (i) {
            case 3: continue;
            case 8: break;
        }
        if (i == 9) goto done;
        hits = hits + 1;
    }
done:
    if (hits < 100) goto finish;
    hits = 0;
finish:
    return hits;
}
