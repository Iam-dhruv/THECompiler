/* '..' cannot begin a number, so the first '.' is a lone T_DOT and only the
   second binds to the digits. The token stream is lexically VALID
   (T_DOT T_FLOAT_CONST) and is rejected by the parser instead, because a bare
   '.' cannot start an expression. Contrast with
   syntax_invalid_bad_numeric_literal.c, which fails one phase earlier. */
int main() {
    int x = ..2131;
    return x;
}
