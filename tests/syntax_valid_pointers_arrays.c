/* ============================================================================
 * syntax_valid_pointers_arrays.c
 * Validates:
 *   - 1D integer and character arrays (with & without size, array initializers)
 *   - Multi-dimensional arrays (2D, 3D matrices)
 *   - Single-level pointers (*p, address-of &, dereference *p)
 *   - Multi-level pointers (**pp, ***ppp)
 *   - Pointer indexing and bracket access
 * ==========================================================================*/

int main() {
    /* 1D Array declarations & initializers */
    int numbers[5] = {10, 20, 30, 40, 50};
    char message[] = "Compiler Design";
    char letters[4] = {'a', 'b', 'c', '\0'};

    /* Multi-dimensional arrays (2D & 3D) */
    int matrix[3][4];
    int tensor[2][3][4];

    /* Array element assignments and accesses */
    matrix[0][0] = 1;
    matrix[1][2] = 42;
    tensor[1][2][3] = matrix[1][2] + numbers[0];

    /* Single-level pointer */
    int val = 100;
    int *ptr = &val;
    *ptr = 200;

    /* Multi-level pointers */
    int **double_ptr = &ptr;
    int ***triple_ptr = &double_ptr;

    ***triple_ptr = 300;

    /* Pointer array indexing */
    int *row_ptr = matrix[0];
    int first_elem = *(row_ptr + 1);

    return 0;
}
