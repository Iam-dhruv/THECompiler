/* A trailing decimal point with no fractional digits is a LEGAL C floating
   constant (C11 6.4.4.2: the fraction part may be empty on either side), and
   gcc accepts it. Kept as a valid test to pin that down.

   This file previously lived in tests/lexer/invalid/ as
   "invalid_malformed_float.c", but produced no lexical errors at all — the
   premise was wrong, not the lexer. */
int main() {
    float x = 1.;
    float y = .5;
    float z = 1.e3;
    return 0;
}
