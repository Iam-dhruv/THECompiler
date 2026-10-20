/* TYPE CHECK — assignment needs a modifiable lvalue and a compatible type. */
int main() {
    int a = 1;
    int b = 2;
    int *p;
    (a + b) = 3;
    5 = a;
    p = 1.5;
    return a;
}
