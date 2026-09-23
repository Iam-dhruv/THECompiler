/* ============================================================================
 * FEATURE 23: Multi-dimensional arrays   (Advanced Features)
 *
 * SYNTAX CHECKS        Declarations of rank 2, 3 and 4, indexing chains of
 *                      matching depth, expression subscripts, and a
 *                      multi-dimensional parameter.
 * LABELLING CHECKS     DEFECT, deliberately pinned by this test.
 *                      TypeInfo carries only a boolean is_array, so RANK AND
 *                      EXTENTS ARE DISCARDED. Every one of these collapses to
 *                      the same label:
 *                        row   (int[5])       -> INT_ARRAY
 *                        grid  (int[2][3])    -> INT_ARRAY
 *                        cube  (int[2][2][2]) -> INT_ARRAY
 *                        hyper (int[2][2][2][2]) -> INT_ARRAY
 *                      A one-dimensional array and a four-dimensional one are
 *                      indistinguishable in the output. Acceptable for
 *                      labelling, but address arithmetic for IR/codegen cannot
 *                      be generated from this — the extents must be retained
 *                      before Stage 4. See FEATURE_PROGRESS.md.
 * NOT A SYNTAX CONCERN Bounds on any dimension, and whether the number of
 *                      subscripts matches the declared rank. `grid[9][9]` and
 *                      the under-subscripted `cube[0]` below both parse.
 * ==========================================================================*/
int sum2d(int m[2][3], int rows, int cols);

int sum2d(int m[2][3], int rows, int cols) {
    int i;
    int j;
    int s = 0;
    for (i = 0; i < rows; i++) {
        for (j = 0; j < cols; j++) {
            s = s + m[i][j];
        }
    }
    return s;
}

int main() {
    int row[5];
    int grid[2][3];
    int cube[2][2][2];
    int hyper[2][2][2][2];
    char board[3][3];

    row[0]             = 1;
    grid[1][2]         = 7;
    cube[1][1][1]      = 9;
    hyper[1][1][1][1]  = 11;
    board[0][0]        = 'x';

    /* expression subscripts */
    int i = 1;
    grid[i][i + 1] = 5;

    /* out of range, and fewer subscripts than the declared rank */
    grid[9][9] = 1;
    int partial = cube[0];

    return sum2d(grid, 2, 3) + partial;
}
