/* A malformed numeric literal is a LEXICAL error, so analysis aborts before
   the parser ever runs — the diagnostic must name the whole bad token rather
   than reporting a confusing downstream syntax error. */
int main() {
    float bad = 1.2.3.4;
    return 0;
}
