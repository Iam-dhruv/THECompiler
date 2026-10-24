/* FEATURE 28 — arrays of function pointers.
 * int (*ops[3])(int, int) is an array of 3 function pointers, 8 bytes each,
 * so ops[i] sits at byte offset i*8 and ops[i](a, b) loads it and calls it
 * indirectly. Initializers may name functions ({add, mul}); missing elements
 * are zeroed. An array decays to a pointer to its first element: ops becomes
 * int(**)(int,int), and a 2-D grid becomes int(*(*)[2])(int,int), a pointer
 * to a row of 2 function pointers. The typedef form binop more[2] is the same
 * type as the written-out one. */
typedef int (*binop)(int, int);
int add(int a, int b) { return a + b; }
int mul(int a, int b) { return a * b; }
int sub(int a, int b) { return a - b; }
int (*table[])(int, int) = {add, mul};
int run(int (*fs[])(int, int), int n) {
    int s = 0;
    for (int i = 0; i < n; i++) s = s + fs[i](i, 2);
    return s;
}
int corner(int (*(*rows)[2])(int, int)) {
    return rows[1][0](1, 1);
}
int main() {
    int (*ops[3])(int, int) = {add, mul};
    ops[2] = sub;
    binop more[2];
    more[0] = ops[1];
    int r = ops[0](1, 2) + (*ops[1])(3, 4) + table[1](5, 6);
    r = r + run(ops, 3);
    int (**walk)(int, int) = ops;
    r = r + (*(walk + 1))(2, 2);
    int (*grid[2][2])(int, int);
    grid[1][0] = add;
    int (*(*row)[2])(int, int) = grid;
    row = row + 1;
    r = r + (*row)[0](7, 8);
    return r + corner(grid) + more[0](2, 3);
}
