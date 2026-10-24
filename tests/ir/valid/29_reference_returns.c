/* FEATURE 29 — functions returning references.
 * int &cell(int i) returns the address of the object it binds to
 * (return &arr + i*4); the call is then an lvalue reached through that
 * address, so cell(2) = 9 stores through it (*t = 9) and reading it loads
 * (t2 = *t). Binding a reference to the call stores the address itself.
 * Returning a reference parameter returns the pointer it already holds.
 * A pointer to a reference-returning function has type int&(*)(int), and a
 * reference to a function pointer, int (*&rfp)(int, int), aliases one. */
int arr[4];
int g;
int &cell(int i) { return arr[i]; }
int &glob() { return g; }
int &pass(int &r) { return r; }
int add(int a, int b) { return a + b; }
int main() {
    cell(2) = 9;
    glob() = glob() + 1;
    int &alias = cell(1);
    alias = 5;
    int r = 0;
    pass(r) = 3;
    int &(*getter)(int) = cell;
    getter(0) = cell(2) + 1;
    int (*op)(int, int) = 0;
    int (*&rfp)(int, int) = op;
    rfp = add;
    return r + op(1, 2) + arr[0];
}
