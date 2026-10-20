/* FEATURE 24 — function overloading.
 * Overloads share a source name but get distinct mangled names. A call is
 * resolved from its arguments: the argument count must match, and an exact
 * match beats one that needs a numeric conversion. */
int add(int a, int b) { return a + b; }
float add(float a, float b) { return a + b; }
int add(int a, int b, int c) { return a + b + c; }
int main() {
    int i = add(1, 2);
    float f = add(1.5, 2.5);
    int t = add(1, 2, 3);
    float g = add(f, 1.0);
    return i + t;
}
