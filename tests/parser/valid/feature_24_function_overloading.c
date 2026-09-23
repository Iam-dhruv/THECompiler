/* ============================================================================
 * FEATURE 24: Function overloading   (Advanced Features)
 *
 * SYNTAX CHECKS        Several functions may share a name while differing in
 *                      parameter count or parameter types. All the
 *                      declarations and definitions below parse.
 * LABELLING CHECKS     KNOWN DEFECT, deliberately pinned by this test.
 *                      A scope's symbol table is an unordered_map keyed by
 *                      NAME ALONE, so each new declaration of `add`
 *                      OVERWRITES the previous one. Only the LAST definition
 *                      to be inserted survives — here `int add(int,int,int)` —
 *                      and every call site resolves to that one regardless of
 *                      its arguments:
 *                        add(1, 2)      -> FUNCTION_CALL(returns:INT)
 *                        add(1.5, 2.5)  -> FUNCTION_CALL(returns:INT)  WRONG
 *                        add(1, 2, 3)   -> FUNCTION_CALL(returns:INT)
 *                      The float call is the visibly wrong one: it should
 *                      report returns:FLOAT. The first and third are right
 *                      only by luck, because the surviving overload happens
 *                      to return int. Correct resolution needs signature-keyed
 *                      symbols (name mangling) plus argument types at the
 *                      call site.
 *                      The three PROTOTYPE/DEFINITION rows do each show their
 *                      own return type correctly — the information is lost
 *                      only at lookup time, not at declaration time.
 *                      See FEATURE_PROGRESS.md, Advanced -> Overloading.
 * NOT A SYNTAX CONCERN Overload RESOLUTION itself — picking the best-matching
 *                      candidate from argument types — is inherently a
 *                      type-checking activity, not a grammar one. Likewise
 *                      ambiguity detection, and the rule that two overloads
 *                      may not differ by return type alone (`int f(int)` vs
 *                      `float f(int)`, declared below, is accepted here).
 * ==========================================================================*/
int   add(int a, int b);
float add(float a, float b);
int   add(int a, int b, int c);

int   add(int a, int b)          { return a + b; }
float add(float a, float b)      { return a + b; }
int   add(int a, int b, int c)   { return a + b + c; }

/* differ by return type only — rejected by real C++, accepted here */
int   ambiguous(int n);
float ambiguous(int n);

int   ambiguous(int n)  { return n; }
float ambiguous(int n)  { return n; }

int main() {
    int   i = add(1, 2);          /* should be the int overload  */
    float f = add(1.5, 2.5);      /* should be the float overload */
    int   t = add(1, 2, 3);       /* should be the 3-arg overload */

    int   a = ambiguous(1);

    return i + t + a;
}
