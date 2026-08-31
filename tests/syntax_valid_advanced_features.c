/* ============================================================================
 * syntax_valid_advanced_features.c — Valid test case specifically exercising:
 *   - Reference declarators (int &ref = a;) and reference parameters
 *   - Standalone until loop: until (cond) { ... }
 *   - Dynamic array allocation: new int[50] and delete[] arr;
 *   - Function pointers: int (*op)(int, int); and calling (*op)(x, y);
 *   - Recursive function calls
 *   - Multi-level pointers and multi-dimensional arrays
 * ==========================================================================*/

int add(int a, int b) {
    return a + b;
}

/* Reference parameter */
void swap(int &a, int &b) {
    int temp = a;
    a = b;
    b = temp;
}

/* Recursive function */
int fibonacci(int n) {
    if (n <= 0) return 0;
    if (n == 1) return 1;
    return fibonacci(n - 1) + fibonacci(n - 2);
}

int main() {
    int x = 10;
    int y = 20;

    /* Reference variable declaration */
    int &ref = x;
    ref = 15;

    swap(x, y);

    /* Standalone until loop */
    until (x >= 50) {
        x += 5;
    }

    /* Do-until loop */
    do {
        y--;
    } until (y <= 0);

    /* Dynamic memory array allocation and delete[] */
    int *dyn_arr = new int[100];
    dyn_arr[0] = 42;
    delete[] dyn_arr;

    /* Single dynamic object allocation and delete */
    int *single_val = new int;
    *single_val = 99;
    delete single_val;

    /* Function pointer declaration and call */
    int (*fp)(int, int);
    fp = add;
    int sum = (*fp)(x, y);
    int direct_sum = fp(x, y);

    /* Recursive call */
    int fib = fibonacci(6);

    /* Multi-level pointer & multi-dim array */
    int matrix[2][3];
    int *p = &matrix[0][0];
    int **pp = &p;
    ***&pp = 123;

    return 0;
}
