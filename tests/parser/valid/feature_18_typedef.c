/* ============================================================================
 * FEATURE 18: typedef   (Advanced Features)
 *
 * SYNTAX CHECKS        A typedef DECLARATION parses in all the usual shapes:
 *                      plain, pointer, array, and over a struct tag.
 * LABELLING CHECKS     The declared name is labelled TYPEDEF_NAME:
 *                        Integer, Text, Buffer, PointAlias -> TYPEDEF_NAME
 *                      This is driven by g_pending_typedef, set when the
 *                      storage-class specifier `typedef` is reduced.
 * KNOWN DEFECT         The name cannot afterwards be USED as a type.
 *                      `Integer x;` is a SYNTAX ERROR, so it cannot appear in
 *                      this (valid) test at all — see the companion test
 *                      tests/parser/invalid/syntax_invalid_typedef_use.c,
 *                      which pins that failure. This is the classic
 *                      typedef-name problem: the lexer must consult the symbol
 *                      table to know `Integer` names a type rather than an
 *                      ordinary identifier, and no such feedback exists.
 *                      A typedef that cannot be used is not yet a usable
 *                      feature. See FEATURE_PROGRESS.md, Advanced -> typedef.
 * NOT A SYNTAX CONCERN Type identity and aliasing rules — that `Integer` and
 *                      `int` denote the same type, and that a typedef creates
 *                      an alias rather than a distinct type. Those are
 *                      semantic notions with no representation here.
 * ==========================================================================*/
struct Point { int x; int y; };

typedef int            Integer;
typedef char          *Text;
typedef int            Buffer[10];
typedef struct Point   PointAlias;

int main() {
    /* The aliases above are declared and labelled, but CANNOT be used as
       type specifiers, so the real types are spelled out here instead. */
    int    plain = 1;
    char  *text;
    int    buffer[10];
    struct Point origin;

    origin.x = 0;
    buffer[0] = plain;

    return plain;
}
