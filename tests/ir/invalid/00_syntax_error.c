/* PHASE 0 — a syntax error stops the pipeline before any IR is written:
 * exit code 1 and no .ir file. */
int main() {
    int x = ;
    return x;
}
