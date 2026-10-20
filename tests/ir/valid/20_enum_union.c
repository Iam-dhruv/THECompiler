/* FEATURE 20 — enum and union.
 * Enumerators are compile-time constants: each is the previous value + 1
 * unless given one, and every use is replaced by its value (including in an
 * array size). An enum variable is an int-sized integer. Every union member
 * sits at offset 0; the union is as large as its largest member. */
enum Color { RED, GREEN = 5, BLUE };
union Value { int i; float f; char bytes[4]; };
int main() {
    enum Color c = BLUE;
    union Value v;
    union Value *vp = &v;
    int table[BLUE];
    v.i = GREEN + 1;
    v.f = 1.5;
    vp->bytes[2] = 'x';
    if (c == BLUE) c = RED;
    return v.i;
}
