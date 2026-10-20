/* FEATURE 04 — while loops, with continue.
 * while M1 (B) M2 S: B.true -> M2, the body loops back to M1 with a goto,
 * continue jumps to the test at M1, and B.false leaves the loop. */
int main() {
    int n = 10;
    int odd = 0;
    while (n > 0) {
        n = n - 1;
        if (n % 2 == 0) continue;
        odd = odd + 1;
    }
    return odd;
}
