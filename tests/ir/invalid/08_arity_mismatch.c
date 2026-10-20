/* TYPE CHECK — a call must match its function's parameter count and types. */
int twice(int x) { return x * 2; }
int main() {
    int a = twice(1, 2);
    int *p;
    a = twice(p);
    a = twice();
    return a;
}
