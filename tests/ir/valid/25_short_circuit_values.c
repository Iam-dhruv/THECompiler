/* FEATURE 25 — short-circuit evaluation and boolean values.
 * Relational/logical operators yield jump code (truelist/falselist). Where a
 * value is needed the jumps become t = 1 / t = 0; where a condition is needed
 * a plain value v becomes "if v goto". The right operand of && / || is
 * skipped once the left one decides; a constant condition needs one jump. */
int main() {
    int x = 3;
    int y = 0;
    int r;
    r = x < y;
    r = !x;
    r = x || y && x;
    r = x ? y : 10;
    if (x && !y) r = 1;
    while (1) { break; }
    return r;
}
