/* ============================================================================
 * syntax_valid_composite_types.c
 * Validates:
 *   - typedef declarations
 *   - enum declarations with named & valued enumerators
 *   - union declarations and member accesses
 *   - struct declarations (named, nested, struct pointers, dot & arrow access)
 *   - static keywords (static variables & static functions)
 *   - printf and scanf function calls
 * ==========================================================================*/

typedef int Integer;
typedef char Character;

enum StatusCode {
    SUCCESS = 0,
    ERROR_NOT_FOUND = 404,
    ERROR_INTERNAL = 500
};

union DataValue {
    int int_val;
    float float_val;
    char char_val;
};

struct Point {
    int x;
    int y;
};

struct Rectangle {
    struct Point top_left;
    struct Point bottom_right;
};

static int g_counter = 0;

static void update_counter() {
    static int local_call_count = 0;
    local_call_count++;
    g_counter += local_call_count;
}

int main() {
    struct Point p1;
    struct Rectangle rect;
    struct Point *p_ptr;
    union DataValue data;
    enum StatusCode code;

    /* Struct member assignments using '.' */
    p1.x = 10;
    p1.y = 20;

    rect.top_left.x = 0;
    rect.top_left.y = 10;
    rect.bottom_right.x = 20;
    rect.bottom_right.y = 0;

    /* Struct pointer member access using '->' */
    p_ptr = &p1;
    p_ptr->x = 30;
    p_ptr->y = 40;

    /* Union member assignment */
    data.int_val = 1024;
    data.float_val = 3.14;

    /* Enum assignment */
    code = SUCCESS;

    /* Static function call */
    update_counter();

    /* Standard I/O function calls (printf & scanf) */
    printf("Point Coordinates: (%d, %d)\n", p_ptr->x, p_ptr->y);
    printf("Rectangle Area Width: %d\n", rect.bottom_right.x - rect.top_left.x);
    scanf("%d", &p1.x);

    return 0;
}
