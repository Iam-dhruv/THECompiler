/* FEATURE 18 — typedef.
 * A typedef registers an alias and emits no code. The lexer asks the symbol
 * table whether an identifier names a typedef and, if so, returns a
 * type-name token — so aliases work as type specifiers, including pointer,
 * array, struct and function-pointer aliases. */
struct Point { int x; int y; };
typedef int Integer;
typedef char *Text;
typedef int Buffer[3];
typedef struct Point PointAlias;
typedef int (*BinOp)(int, int);
int sub(int a, int b) { return a - b; }
int main() {
    Integer n = 2;
    Text t = "ok";
    Buffer b;
    PointAlias p;
    BinOp f = sub;
    b[1] = n;
    p.y = f(n, 1);
    return p.y;
}
