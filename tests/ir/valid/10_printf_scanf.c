/* FEATURE 10 — printf and scanf.
 * Built-in library functions (no prototype needed): arguments pass as-is,
 * one param each, left to right, then "t = call printf, n". String literals
 * live in .data as .strN — a .strN operand is the string's address — and
 * identical literals share one entry. scanf receives addresses. */
int main() {
    int n = 5;
    float f = 1.5;
    printf("hello\n");
    printf("%d\n", n * 2 + 1);
    printf("%d %f\n", n, f);
    scanf("%d", &n);
    printf("%d\n", n);
    return n;
}
