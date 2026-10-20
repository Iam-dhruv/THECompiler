/* TYPE CHECK — * needs a pointer; . and -> need a struct/union (or a pointer
 * to one) that has the member; [] needs an integer index. */
struct P { int x; };
int main() {
    int n = 1;
    struct P s;
    int a[3];
    n = *n;
    n = s.z;
    n = n.x;
    n = a[1.5];
    return n;
}
