/* FEATURE 13 — the static keyword.
 * Globals and static locals live in .data, not in the function's frame. A
 * static local is renamed <function>.<name> and keeps its value between
 * calls: its (constant) initializer is folded into .data and never re-run on
 * entry. Static storage without an initializer is zero. */
static int counter;
static int limit = 100;
static int bump(int by) {
    static int hidden;
    static int calls = 1;
    hidden = hidden + by;
    calls = calls + 1;
    counter = counter + by;
    return hidden;
}
int main() {
    static int cache[4];
    static int *slot = &cache[0];
    cache[1] = 7;
    *slot = 2;
    bump(1);
    return counter + limit;
}
