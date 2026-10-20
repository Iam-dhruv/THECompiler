/* FEATURE 03 — for loops.
 * for (init; M1 B; M2 incr N) M3 S: B.true -> M3, the body falls into the
 * increment at M2, and N jumps back to the test at M1. A declaration in the
 * init is scoped to the loop; an omitted condition is always true. */
int main() {
    int sum = 0;
    for (int i = 0; i < 4; i++) {
        sum = sum + i;
    }
    for (;;) {
        sum = sum - 1;
        if (sum < 0) break;
    }
    return sum;
}
