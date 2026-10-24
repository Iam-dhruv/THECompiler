/* TYPE CHECK — declarations C++ rejects: arrays of references (written out,
 * parenthesized, or through a reference typedef), pointers to references,
 * arrays of functions. A reference return must bind an lvalue of exactly the
 * return type that outlives the call, and an array of function pointers is
 * not itself callable or assignable. */
typedef int &IntRef;
typedef int F(int, int);
int add(int a, int b) { return a + b; }
int g;
int &bad_local() { int x = 1; return x; }
int &bad_rvalue() { return g + 1; }
int &bad_type() { float f; return f; }
int get();
int &get();
int main() {
    int &refs[2];
    int (&inner[2]);
    IntRef more[3];
    IntRef *pr;
    F funcs[2];
    int f2[2](int);
    int (*ops[2])(int, int);
    ops(1, 2);
    int (*plain)() = bad_local;
    return 0;
}
