/* ============================================================================
 * FEATURE 20: enum and union   (Advanced Features)
 *
 * SYNTAX CHECKS        Tag declarations with bodies, implicit and explicit
 *                      enumerator values, variables of enum/union type, union
 *                      member access, and a union nested in a struct.
 * LABELLING CHECKS     THE POINT OF THIS TEST:
 *                        Color, Status -> ENUM_TAG
 *                        Value, Packet -> UNION_TAG
 *                        RED, GREEN, BLUE, OK, FAIL -> ENUM_CONSTANT
 *                        c, s   -> ENUM_VARIABLE
 *                      (the union's char member is named `ch`, not
 *                      `c`, so the table stays unambiguous to read)
 *                        v      -> UNION_VARIABLE
 *                        vp     -> UNION_POINTER
 *                      Enum bodies are scoped `enum:Color`, union bodies
 *                      `union:Value`. Enumerators are inserted GLOBALLY, which
 *                      matches real C: an enum body does not create a
 *                      namespace, so RED is visible in `main`.
 * NOT A SYNTAX CONCERN Enum: that an assigned value is one of the declared
 *                      enumerators (`c = 999;` parses), and enumerator value
 *                      collisions. Union: the defining property that only ONE
 *                      member is active at a time — writing v.i then reading
 *                      v.f is accepted here and is a runtime/semantic matter.
 *                      Member offsets and union size are likewise not
 *                      computed; they will be needed for codegen.
 * ==========================================================================*/
enum Color  { RED, GREEN, BLUE };
enum Status { OK = 0, FAIL = -1 };

union Value  { int i; float f; char ch; };
union Packet { int header; char bytes[4]; };

struct Tagged { int kind; union Value payload; };

int main() {
    enum Color  c;
    enum Status s;
    union Value  v;
    union Value *vp;
    union Packet p;
    struct Tagged t;

    c = GREEN;
    s = OK;

    v.i = 100;
    v.f = 1.5;          /* overwrites v.i — not diagnosed */
    vp = &v;
    vp->ch = 'x';

    p.header = 1;
    p.bytes[0] = 'a';

    t.kind = 1;
    t.payload.i = 7;

    /* value outside the declared enumerators: accepted */
    c = 999;

    return v.i;
}
