/* FEATURE 23 — multi-dimensional arrays.
 * Row-major layout: in int m[2][3], m[i][j] is at byte i*12 + j*4, and
 * constant indices fold to one offset. Nested braces initialize row by row;
 * without inner braces, elements fill the rows in order (brace elision).
 * A 2-D array decays to a pointer to its first row, int(*)[3] — the type of
 * a parameter written int m[][3] — and indexing that pointer steps by rows. */
int corner(int m[][3], int r) {
    return m[r][2];
}
int main() {
    int m[2][3] = {{1, 2, 3}, {4}};
    int flat[2][2] = {1, 2, 3, 4};
    int i = 1;
    int j = 2;
    m[i][j] = m[0][1] + flat[1][0];
    int (*row)[3] = m;
    row[1][0] = corner(m, i);
    return m[1][2];
}
