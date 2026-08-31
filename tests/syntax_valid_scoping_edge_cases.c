/* ============================================================================
 * syntax_valid_scoping_edge_cases.c
 * Stress-tests the scope-stack + semantic classification system itself:
 *   - Variable shadowing across nested blocks (same name, innermost wins)
 *   - A parameter shadowed by block-local variables of the same name
 *   - Deeply nested blocks (3+ levels) and their scope-name chaining
 *   - Locally-defined struct/enum inside a function body
 *   - goto/label forward and backward references
 *   - switch-case bodies (no block scope of their own)
 *   - A single declaration introducing mixed plain/pointer/array declarators
 *   - Use of an identifier that is never declared (UNDECLARED_IDENTIFIER)
 * ==========================================================================*/

int counter = 0;               /* global, shadowed inside main() and shadow_demo() */

int shadow_demo(int counter) { /* parameter shadows the global */
    int result = counter;
    {
        int counter = 100;      /* shadows the parameter */
        result += counter;
        {
            int counter = 200;  /* shadows the block-local above */
            result += counter;
        }
    }
    return result;
}

int main() {
    int counter = 5;            /* shadows the global, in main's own scope */

    /* mixed declarators in a single declaration */
    int a, *p, arr[3], **pp;
    a = 1;
    p = &a;
    arr[0] = a;
    pp = &p;

    /* locally-defined struct/enum */
    struct Local {
        int tag;
    };
    struct Local L;
    L.tag = 1;

    enum LocalKind { KIND_A, KIND_B };
    enum LocalKind k = KIND_A;

    /* deeply nested blocks */
    {
        int level = 1;
        {
            int level = 2;
            {
                int level = 3;
                counter += level;
            }
        }
    }

    /* switch: no block scope of its own; a case-local declaration is
       visible to later cases (fallthrough semantics) */
    switch (counter) {
        case 5: {
            int handled = 1;
            counter += handled;
            break;
        }
        default:
            break;
    }

    /* goto: a forward reference then a backward one */
    goto skip;
    counter = -1;
skip:
    counter += 1;

loop_top:
    counter++;
    if (counter < 10) goto loop_top;

    int total = shadow_demo(counter);

    /* an identifier that was never declared anywhere */
    total = total + never_declared;

    return total;
}
