/* FEATURE 08 — pointers.
 * &x takes an address; *p is an lvalue read as t = *p and written as
 * *p = v. pointer + integer is scaled by the pointee size, pointer - pointer
 * is divided by it, and p++ steps one element. An array decays to the
 * address of its first element. */
int main() {
    int x = 10;
    int arr[3];
    int *p = &x;
    int *q;
    *p = *p + 1;
    q = arr;
    q = q + 2;
    *q = x;
    q++;
    int d = q - arr;
    if (p != 0) x = 0;
    return d;
}
