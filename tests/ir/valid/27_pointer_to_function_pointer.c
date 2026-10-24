/* FEATURE 27 — pointers to function pointers.
 * int (**pp)(int, int) points at a function pointer. Only a function pointer
 * itself is callable: (*pp)(a, b) loads the function pointer and calls it
 * indirectly, and in (**pp)(a, b) the second * just names the function, so
 * no extra load is emitted. A typedef'd function pointer composes the same
 * way: binop *q is int(**)(int,int). Writing through the pointer (*out = f)
 * changes which function the pointed-at pointer calls. */
typedef int (*binop)(int, int);
int add(int a, int b) { return a + b; }
int mul(int a, int b) { return a * b; }
void pick(int (**out)(int, int), int (*f)(int, int)) { *out = f; }
int main() {
    int (*op)(int, int) = add;
    int (**pp)(int, int) = &op;
    int r = (*pp)(2, 3);
    *pp = mul;
    r = r + (**pp)(4, 5);
    pick(&op, add);
    int (***ppp)(int, int) = &pp;
    r = r + (**ppp)(1, 2);
    binop *q = pp;
    return r + (*q)(1, 1) + op(6, 7);
}
