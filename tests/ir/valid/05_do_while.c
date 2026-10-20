/* FEATURE 05 — do-while loops.
 * do M1 S while M2 (B): the body runs first and falls into the test at M2,
 * B.true jumps back to M1, and continue goes to the test. */
int main() {
    int i = 0;
    int total = 0;
    do {
        i++;
        if (i == 2) continue;
        total += i;
    } while (i < 5);
    return total;
}
