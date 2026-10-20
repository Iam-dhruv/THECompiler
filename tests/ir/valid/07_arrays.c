/* FEATURE 07 — integer and char arrays.
 * Indexed quads address bytes: a[i] is the object i*4 bytes into a, so the
 * index is scaled by the element size (1 for char: no multiply). A brace
 * initializer stores each element and zero-fills the rest; an omitted size
 * comes from the initializer; a char array can be initialized from a
 * string literal, including its '\0'. */
int main() {
    int a[4] = {5, 6};
    int b[] = {1, 2, 3};
    char s[] = "hi";
    int i = 2;
    a[i] = a[0] + b[i];
    s[1] = 'o';
    return a[3];
}
