/* FEATURE 21 — until loops (this language's extension), both forms.
 * until (B) S repeats S while B is false: a while loop with B's true and
 * false exits swapped. do S until (B) mirrors do-while the same way. */
int main() {
    int n = 0;
    until (n >= 3) {
        n = n + 1;
    }
    do {
        n = n * 2;
    } until (n > 20);
    return n;
}
