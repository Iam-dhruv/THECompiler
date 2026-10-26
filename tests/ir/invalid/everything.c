// ============================================================================
// PURE LEXICAL & SYNTACTIC VALIDITY — SEMANTIC ERROR TORTURE TEST
// Every statement below is 100% syntactically valid, but violates semantic rules.
// ============================================================================

// 1. TYPEDEF, ENUM, STRUCT, UNION DECLARATIONS
typedef int MyInt;
typedef float MyFloat;

enum Color {
    RED = 1,
    GREEN = 2,
    BLUE = 3
};

enum Status {
    OK = 0,
    RED = 5
    // SEMANTIC ERROR 1: Enumerator 'RED' redeclared in the same scope
};

union Data {
    int i;
    float f;
};

struct Point {
    int x;
    int y;
    int x;
    // SEMANTIC ERROR 2: Duplicate member 'x' inside struct definition
};

struct Node {
    int val;
    struct Point pt;
    union Data d;
    struct Node* next;
};

typedef struct Node NodeBox;


// 2. FUNCTION OVERLOADING & STATIC / REFERENCE DECLARATIONS
int overloaded_fn(int a, int b) {
    return a + b;
}

float overloaded_fn(int a, int b) {
    // SEMANTIC ERROR 3: Cannot overload functions distinguished by return type alone
    return 1.5;
}

int overloaded_fn(float a, float b) {
    return 0;
}

void ref_and_return_errors(int& ref_param) {
    int local_v;
    local_v = 10;
    return local_v;
    // SEMANTIC ERROR 4: Void function returning a value
}

int missing_return_value(int x) {
    if (x > 0) {
        return;
        // SEMANTIC ERROR 5: Non-void function with empty return statement
    }
    return 1.5;
    // SEMANTIC ERROR 6: Returning float (if strict) or test below for struct return
}


// 3. OPERATOR TYPE CHECKING, LVALUE VIOLATIONS, & POINTER ARITHMETIC
void test_operator_semantics() {
    int a;
    int b;
    float f1;
    float f2;
    int* p1;
    int* p2;
    float* pf;
    struct Point pt1;
    struct Point pt2;

    a = 10;
    b = 20;
    f1 = 2.5;
    f2 = 3.5;

    // SEMANTIC ERROR 7: Modulo (%) and Bitwise (&, |, ^, <<, >>, ~) require integer operands
    a = f1 % f2;
    a = f1 & b;
    a = f1 << 2;
    a = ~f2;

    // SEMANTIC ERROR 8: Invalid binary operation on two pointers (Pointer + Pointer, Pointer * Pointer)
    p1 = &a;
    p2 = &b;
    p1 = p1 + p2;
    p1 = p1 * 2;

    // SEMANTIC ERROR 9: Incompatible pointer type assignment (float* to int* without cast)
    pf = &f1;
    p1 = pf;

    // SEMANTIC ERROR 10: Arithmetic / Logical operators applied directly to structs
    pt1 = pt1 + pt2;
    if (pt1 && pt2) {
        a = 1;
    }

    // SEMANTIC ERROR 11: Lvalue required as left operand of assignment / increment / address-of
    (a + b) = 30;
    10 = a;
    (a + 1)++;
    p1 = &(a + b);
}


// 4. ARRAYS, MULTIDIMENSIONAL INDEXING, & STRUCT/UNION MEMBER ACCESS
void test_array_and_struct_semantics() {
    int arr[10];
    int matrix[3][4];
    int scalar;
    float bad_idx;
    struct Node n;
    struct Node* n_ptr;
    union Data u;

    scalar = 5;
    bad_idx = 1.5;

    // SEMANTIC ERROR 12: Array subscript is not an integer (using float or pointer as index)
    arr[bad_idx] = 10;
    matrix[1][bad_idx] = 20;
    arr[n_ptr] = 30;

    // SEMANTIC ERROR 13: Subscripting a non-array / non-pointer variable
    scalar[0] = 5;
    n[1] = 10;

    // SEMANTIC ERROR 14: Unassignable array name (Array decay / non-modifiable lvalue)
    arr = &scalar;
    matrix[0] = &scalar;

    // SEMANTIC ERROR 15: Using '.' on a pointer and '->' on a non-pointer struct/union
    n_ptr = &n;
    n_ptr.val = 10;
    n->val = 20;
    scalar.x = 5;

    // SEMANTIC ERROR 16: Accessing non-existent member in struct/union
    n.pt.z = 100;
    u.missing_field = 1;
}


// 5. CONTROL FLOW SEMANTICS (Loops, Switch, Break, Continue, Goto)
void test_control_flow_semantics() {
    int x;
    float flt;
    struct Point pt;

    x = 1;
    flt = 3.14;

    // SEMANTIC ERROR 17: Break and Continue used outside of any loop or switch
    break;
    continue;

    // SEMANTIC ERROR 18: Switch condition is not an integer/enum type (using float and struct)
    switch (flt) {
        case 1:
            x = 2;
            break;
        default:
            x = 0;
            break;
    }

    switch (pt) {
        default:
            break;
    }

    // SEMANTIC ERROR 19: Non-constant case label, duplicate case value, and continue inside switch (outside loop)
    switch (x) {
        case x:
            x = 10;
            break;
        case 1:
            x = 20;
            break;
        case 1:
            x = 30;
            continue;
        default:
            x = 40;
        default:
            x = 50;
    }

    // SEMANTIC ERROR 20: Non-boolean / non-scalar condition in if, while, do-while, until, do-until, for
    if (pt) {
        x = 1;
    }

    while (pt) {
        x = 2;
    }

    do {
        x = 3;
    } while (pt);

    until (pt) {
        x = 4;
    }

    do {
        x = 5;
    } until (pt);

    for (x = 0; pt; x++) {
        x = 6;
    }

    // SEMANTIC ERROR 21: Goto to an undeclared label & duplicate label definition
    goto non_existent_label;

dup_label:
    x = 1;
dup_label:
    x = 2;
}


// 6. FUNCTION CALLS, RECURSION, REFERENCES, & FUNCTION POINTERS
int target_func(int a, float b, int& c) {
    if (a <= 0) {
        return c;
    }
    // SEMANTIC ERROR 22: Recursive call passing a literal (rvalue) to a non-const reference parameter 'int& c'
    return target_func(a - 1, b, 100);
}

void test_calls_and_func_ptrs() {
    int x;
    int res;
    struct Point pt;
    int (*fp)(int, int);

    x = 5;

    // SEMANTIC ERROR 23: Calling a non-function variable as a function
    res = x(1, 2);

    // SEMANTIC ERROR 24: Wrong number of arguments (too few and too many)
    res = target_func(1);
    res = target_func(1, 2.5, x, 99);

    // SEMANTIC ERROR 25: Incompatible argument types in function call
    res = target_func(pt, pt, x);

    // SEMANTIC ERROR 26: Ambiguous / non-matching overloaded function call
    res = overloaded_fn(1, 2.5);
    res = overloaded_fn(pt, pt);

    // SEMANTIC ERROR 27: Assigning incompatible function signature to function pointer
    fp = &target_func;
    res = fp(1);
}


// 7. SCOPING, REDECLARATION, UNDECLARED IDENTIFIERS, & I/O
int main(int argc, char** argv) {
    int a;
    int a;
    // SEMANTIC ERROR 28: Redeclaration of variable 'a' in the same scope

    static int s_var;
    static int s_var;
    // SEMANTIC ERROR 29: Redeclaration of static variable in the same scope

    struct Node io_node;

    // SEMANTIC ERROR 30: Undeclared identifier usage
    undeclared_var = 42;
    undeclared_func(a);

    // Multilevel I/O Semantic Errors (e.g., passing non-pointer / wrong type to scanf, or indexing non-array in I/O)
    scanf("%d", io_node.val);
    printf("%d\n", io_node.pt[0]);

    // Returning a struct from main which expects 'int' return type
    return io_node;
}