/* ============================================================================
 * FEATURE 09: Structures   (Basic Features)
 *
 * SYNTAX CHECKS        Tag declaration with a body, variables of struct type,
 *                      pointer-to-struct, nested structs, `.` and `->` member
 *                      access, and a struct passed as a parameter.
 * LABELLING CHECKS     THE POINT OF THIS TEST:
 *                        Point    -> STRUCT_TAG
 *                        origin   -> STRUCT_VARIABLE
 *                        pptr     -> STRUCT_POINTER
 *                        box      -> STRUCT_VARIABLE
 *                        p        -> STRUCT_PARAMETER  (in scope `area`)
 *                      Fields declared inside the body are labelled in their
 *                      own scope: `x`/`y` are INT_VARIABLE in scope
 *                      `struct:Point`.
 * NOT A SYNTAX CONCERN Member *access* is deliberately unlabelled. The
 *                      identifier after `.` or `->` keeps Token_Type ==
 *                      Token_Name, because this compiler has one flat scope
 *                      stack rather than a per-struct member namespace — a
 *                      lookup there would wrongly resolve to an unrelated
 *                      same-named symbol. Documented in parser.y's header.
 *                      Also not checked: whether the named member exists,
 *                      field offsets/sizes, and `.` vs `->` being used on the
 *                      correct one of value vs pointer.
 * ==========================================================================*/
struct Point { int x; int y; };
struct Rect  { struct Point corner; int w; int h; };

int area(struct Point p);

int area(struct Point p) {
    return p.x * p.y;
}

int main() {
    struct Point  origin;
    struct Point *pptr;
    struct Rect   box;

    origin.x = 3;
    origin.y = 4;

    pptr = &origin;
    pptr->x = 5;
    pptr->y = 6;

    /* nested member access */
    box.corner.x = 1;
    box.w = 10;
    box.h = 20;

    return area(origin) + box.w;
}
