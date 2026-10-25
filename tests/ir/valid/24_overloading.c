/* FEATURE 24 — function overloading.
 * Overloads share a source name but get distinct mangled names. A call is
 * resolved from its arguments via Pareto dominance (C++ style): a candidate
 * that is strictly better on at least one argument and no worse on any beats
 * all others. Ties where neither candidate dominates remain ambiguous. */
int add(float a, float b) { return a + b; }
float add(double a, double b) { return a + b; }
int add(int a, int b, int c) { return a + b + c; }
int main() {
    int i = add(1, 2.5);
    float f = add(1.5, 2.5);
    int t = add(1, 2, 3);
    float g = add(f, 1);
    return i + t;
}

