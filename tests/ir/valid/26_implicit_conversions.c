/* TYPE CHECKING — usual arithmetic conversions.
 * int <-> float and float <-> double conversions appear as explicit cast
 * quads; conversions of literals are folded; char and int share the integer
 * class and need no cast. Floating literals have type float. */
int main() {
    int i = 5;
    float f = 2.5;
    double d;
    char ch = 'A';
    f = i + f;
    i = f * 2;
    d = f;
    d = d + 1;
    f = 3;
    i = 7.9;
    i = ch + 1;
    return i;
}
