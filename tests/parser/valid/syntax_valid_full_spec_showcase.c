/* ============================================================================
 * syntax_valid_full_spec_showcase.c
 *
 * One program exercising EVERY feature in the project specification, so a
 * single run demonstrates the whole supported language.
 *
 *   BASIC     all arithmetic/relational/logical/bitwise operators, if-else,
 *             for, while, do-while, switch, arrays (int + char), pointers,
 *             struct, printf/scanf, function calls with arguments,
 *             goto/break/continue, static
 *   ADVANCED  recursion, dynamic memory, function pointers, command-line
 *             input, typedef, references, enum, union, until loop,
 *             multi-level pointers, multi-dimensional arrays, overloading
 *
 * Written within the language's documented limits: no preprocessor
 * directives, no C-style casts or sizeof, no varargs prototypes, and
 * typedef'd names are declared but not reused as type specifiers.
 * ==========================================================================*/

/* ---- Composite types: struct, union, enum, typedef ---------------------- */
struct Point { int x; int y; };
union  Value { int i; float f; char c; };
enum   Color { RED, GREEN = 5, BLUE };
typedef int Integer;

/* ---- Prototypes (also enable mutual recursion) and overloaded names ----- */
int   add(int a, int b);
float add(float a, float b);
int   factorial(int n);
int   is_even(int n);
int   is_odd(int n);
void  show(struct Point p);

/* ---- static storage class ----------------------------------------------- */
static int call_count;

/* ---- Function overloading: same name, different parameter types --------- */
int   add(int a, int b)       { return a + b; }
float add(float a, float b)   { return a + b; }

/* ---- Recursion ----------------------------------------------------------- */
int factorial(int n) {
    if (n <= 1) { return 1; }
    return n * factorial(n - 1);
}

/* ---- Mutual recursion resolved through the prototypes above -------------- */
int is_even(int n) {
    if (n == 0) { return 1; }
    return is_odd(n - 1);
}
int is_odd(int n) {
    if (n == 0) { return 0; }
    return is_even(n - 1);
}

/* ---- struct passed by value, member access ------------------------------- */
void show(struct Point p) {
    printf("(%d, %d)\n", p.x, p.y);
}

/* ---- Command line input: argc / argv ------------------------------------- */
int main(int argc, char *argv[]) {

    /* ---- Arithmetic operators -------------------------------------------- */
    int a = 12;
    int b = 5;
    int sum  = a + b;
    int diff = a - b;
    int prod = a * b;
    int quot = a / b;
    int rem  = a % b;
    int neg  = -a;
    int pos  = +b;

    /* ---- Relational operators --------------------------------------------- */
    int lt = a <  b;
    int gt = a >  b;
    int le = a <= b;
    int ge = a >= b;
    int eq = a == b;
    int ne = a != b;

    /* ---- Logical operators ------------------------------------------------- */
    int land = (a > 0) && (b > 0);
    int lor  = (a > 0) || (b > 0);
    int lnot = !lt;

    /* ---- Bitwise operators -------------------------------------------------- */
    int band = a & b;
    int bor  = a | b;
    int bxor = a ^ b;
    int bnot = ~a;
    int shl  = a << 2;
    int shr  = a >> 1;

    /* ---- Compound assignment, increment / decrement -------------------------- */
    a += 1;  a -= 1;  a *= 2;  a /= 2;  a %= 7;
    a &= 15; a |= 1;  a ^= 3;  a <<= 1; a >>= 1;
    a++; ++a; a--; --a;

    /* ---- Ternary conditional -------------------------------------------------- */
    int max = (a > b) ? a : b;

    /* ---- Arrays: integer, char, and multi-dimensional -------------------------- */
    int  numbers[5];
    char name[16];
    int  grid[2][3];
    int  cube[2][2][2];
    numbers[0]    = 10;
    name[0]       = 'A';
    grid[1][2]    = 7;
    cube[1][1][1] = 9;

    /* ---- Pointers, multi-level pointers, and a reference ----------------------- */
    int    value = 42;
    int   *p     = &value;
    int  **pp    = &p;
    int ***ppp   = &pp;
    int   &ref   = value;
    *p     = 43;
    **pp   = 44;
    ***ppp = 45;
    ref    = 46;

    /* ---- struct / union / enum values ------------------------------------------ */
    struct Point  origin;
    struct Point *pptr;
    union  Value  v;
    enum   Color  c;
    origin.x = 0;
    origin.y = 0;
    pptr     = &origin;
    pptr->x  = 1;
    v.i      = 100;
    c        = GREEN;

    /* ---- Function pointer: declaration, assignment, both call forms ------------- */
    int (*op)(int, int);
    op = add;
    int viaptr   = op(2, 3);
    int viaderef = (*op)(4, 5);

    /* ---- Dynamic memory allocation ---------------------------------------------- */
    int *heap_one  = new int;
    int *heap_many = new int[10];
    delete heap_one;
    delete [] heap_many;

    /* ---- printf / scanf ---------------------------------------------------------- */
    printf("argc = %d\n", argc);
    printf("%s\n", argv[0]);
    scanf("%d", &value);

    /* ---- if / else if / else ------------------------------------------------------ */
    if (a > b)      { max = a; }
    else if (a < b) { max = b; }
    else            { max = 0; }

    /* ---- for loop, with continue and break ----------------------------------------- */
    int i;
    int total = 0;
    for (i = 0; i < 5; i++) {
        if (i == 0) { continue; }
        if (i == 4) { break; }
        total += numbers[0];
    }
    for (;;) { break; }

    /* ---- while loop ------------------------------------------------------------------ */
    int w = 3;
    while (w > 0) { w--; }

    /* ---- do-while loop ---------------------------------------------------------------- */
    int d = 0;
    do { d++; } while (d < 3);

    /* ---- until loop, both supported forms ---------------------------------------------- */
    int u = 0;
    do { u++; } until (u >= 3);
    until (u >= 6) { u++; }

    /* ---- switch / case / default / break ------------------------------------------------ */
    switch (c) {
        case RED:   total = 1; break;
        case GREEN: total = 2; break;
        default:    total = 0; break;
    }

    /* ---- goto with a backward and a forward label ----------------------------------------- */
    i = 0;
again:
    i++;
    if (i < 2) { goto again; }
    goto done;
done:

    /* ---- Calls: recursion, overloads, struct argument -------------------------------------- */
    call_count++;
    total = factorial(5) + add(1, 2) + is_even(4);
    show(origin);

    return 0;
}
