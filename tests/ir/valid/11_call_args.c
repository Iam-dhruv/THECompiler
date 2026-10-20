/* FEATURE 11 — function calls with arguments.
 * User functions are named name@<param codes> (i int, c char, f float,
 * d double, P pointer, v no parameters); main keeps its name. A call
 * evaluates its arguments left to right, converts each to its parameter
 * type, emits one param per argument, then "t = call f, n". A void call has
 * no result. A body that can fall off its end gets an implicit return. */
float scale(int x, float k) {
    return x * k;
}
void log_value(char c, int v) {
    v = v + c;
}
int pick() {
    return 4;
}
int main() {
    float r;
    r = scale(pick(), 2);
    log_value('a', 3);
    return r;
}
