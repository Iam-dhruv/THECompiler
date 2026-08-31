/* ============================================================================
 * syntax_valid_advanced.c — Valid test case for advanced language features:
 *   - Recursive function calls (factorial / fibonacci)
 *   - Command-line arguments (argc, argv)
 *   - Multi-level pointers (int** pp)
 *   - Multi-dimensional arrays (int matrix[3][4])
 *   - Composite types (struct, union, enum, typedef)
 *   - Static storage specifiers
 *   - do-until loops
 *   - Standard I/O function calls (printf, scanf)
 * ==========================================================================*/

typedef int Integer;

enum Status {
    STATUS_OK,
    STATUS_ERROR,
    STATUS_PENDING
};

union DataHolder {
    int i_val;
    float f_val;
    char c_val;
};

struct Node {
    int value;
    struct Node *next;
};

/* Recursive function definition */
int factorial(int n) {
    if (n <= 1) {
        return 1;
    }
    return n * factorial(n - 1);
}

/* Function with multi-level pointer and multi-dimensional array */
int process_matrix(int matrix[3][4], int **pptr) {
    int i, j;
    int sum = 0;
    static int call_count = 0;
    call_count++;

    for (i = 0; i < 3; i++) {
        for (j = 0; j < 4; j++) {
            matrix[i][j] = i * 4 + j;
            sum += matrix[i][j];
        }
    }

    if (pptr != 0 && *pptr != 0) {
        **pptr = sum;
    }

    return sum;
}

int main(int argc, char *argv[]) {
    int grid[3][4];
    int val = 0;
    int *ptr = &val;
    int **pptr = &ptr;
    int fact_res;
    int count = 0;
    union DataHolder data;
    enum Status current_status = STATUS_OK;

    data.i_val = 42;

    /* I/O calls */
    printf("Processing arguments count: %d\n", argc);

    fact_res = factorial(5);

    process_matrix(grid, pptr);

    /* Until loop demonstration */
    do {
        count++;
    } until (count >= 10);

    return 0;
}
