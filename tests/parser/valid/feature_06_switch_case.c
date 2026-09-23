/* ============================================================================
 * FEATURE 06: switch / case / default   (Basic Features)
 *
 * SYNTAX CHECKS        `switch` with multiple `case` labels, a `default`
 *                      label, `break` statements, deliberate fallthrough
 *                      (a case with no body), an empty switch body, and a
 *                      `default` that is not last.
 * LABELLING CHECKS     `choice`/`result` are INT_VARIABLE in `main`. A case
 *                      label's constant expression is an ordinary expression,
 *                      so an enum constant used as a label still labels as
 *                      ENUM_CONSTANT.
 * NOT A SYNTAX CONCERN Duplicate case values, a `case` whose value is not a
 *                      compile-time constant, non-integer switch operands, and
 *                      missing `break` (accidental fallthrough) are all
 *                      accepted here. Detecting them requires constant
 *                      evaluation and type checking — later stages.
 * ==========================================================================*/
enum Color { RED, GREEN, BLUE };

int main() {
    int choice = 2;
    int result = 0;
    enum Color c;
    c = GREEN;

    switch (choice) {
        case 1:  result = 10; break;
        case 2:  result = 20; break;
        case 3:                        /* deliberate fallthrough */
        case 4:  result = 40; break;
        default: result = 0;  break;
    }

    /* default need not come last */
    switch (choice) {
        default: result = 1; break;
        case 9:  result = 2; break;
    }

    /* enum constant as a case label */
    switch (c) {
        case RED:   result = 100; break;
        case GREEN: result = 200; break;
        case BLUE:  result = 300; break;
    }

    /* empty switch body */
    switch (choice) { }

    return result;
}
