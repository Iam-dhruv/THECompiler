/* TYPE CHECK — overload resolution: ambiguous when two overloads fit equally
 * well, an error when none fits. */
int f(int a, float b) { return a; }
int f(float a, int b) { return b; }
int main() {
    int x = f(1, 2);
    char *s;
    x = f(s, s);
    return x;
}
