/* FEATURE 06 — switch / case / default.
 * The operand is copied into a temp once, then control jumps to a test chain
 * emitted after the bodies ("if t == v goto case"). Bodies are laid out in
 * source order, so falling through into the next case is straight-line flow;
 * break jumps past the switch. */
int main() {
    int day = 3;
    int kind = 0;
    switch (day) {
        case 1:
            kind = 10;
            break;
        case 2:
        case 3:
            kind = 20;
        case 4:
            kind = kind + 1;
            break;
        default:
            kind = -1;
    }
    return kind;
}
