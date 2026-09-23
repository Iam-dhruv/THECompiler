/* ============================================================================
 * FEATURE 18 companion: typedef name used as a type   (must FAIL)
 *
 * Pins the known typedef defect. `typedef int Integer;` is accepted and
 * labels Integer as TYPEDEF_NAME (see
 * tests/parser/valid/feature_18_typedef.c), but the alias cannot then be
 * USED as a type specifier: the declaration below is a syntax error.
 *
 * This is the classic typedef-name problem. The grammar decides whether a
 * token begins a declaration purely from the token's class, and the lexer
 * returns `Integer` as a plain T_IDENTIFIER because nothing feeds the symbol
 * table back into it. A real C compiler resolves this with the "lexer hack":
 * the lexer looks each identifier up and returns a distinct TYPEDEF_NAME
 * token class for names previously introduced by a typedef.
 *
 * Expected: syntax error at the line using `Integer` as a type.
 * ==========================================================================*/
typedef int Integer;

int main() {
    Integer x;
    x = 5;
    return x;
}
