/* Maximal munch around '.' — the lexer decides between T_DOT and the start
   of a number by looking at whether a DIGIT immediately follows.
   All of these are LEXICALLY valid token sequences (the parser may still
   reject some of them; that is a separate concern). */
struct P { int x; float y; };

int main() {
    struct P p;
    struct P arr[2];

    p.x = 1;              /* '.' then identifier  -> T_DOT                */
    p.y = .5;             /* '.' then digit       -> T_FLOAT_CONST        */
    arr[0].y = 1.;        /* trailing dot binds to the number, not to ']' */

    /* '..' cannot begin a number (second char is not a digit), so the
       first '.' stands alone as T_DOT and only the LAST '.' binds to the
       digits that follow: T_DOT T_DOT T_FLOAT_CONST */
    float z = ..2131;
    return p.x;
}
