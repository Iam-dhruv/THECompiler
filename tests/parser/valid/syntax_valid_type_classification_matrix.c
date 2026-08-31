/* ============================================================================
 * syntax_valid_type_classification_matrix.c
 * Deliberately exercises base-type x modifier x role combinations that the
 * other fixtures don't already cover:
 *   - char/float/double plain variables and their pointer forms
 *   - char/float/double parameters, plain and pointer
 *   - an unsized array parameter (int nums[])
 *   - struct/union/enum/class pointer parameters
 *   - a full void-procedure chain: prototype -> definition -> two call sites
 *     (one forward-referencing the prototype, one after the real definition)
 * ==========================================================================*/

struct Point { int x; int y; };
union Cell { int i; float f; };
enum Mode { MODE_A, MODE_B };
class Widget { public: int id; };

void log_event(char *tag);   /* prototype: PROCEDURE_PROTOTYPE */

void take_all(char c, float f, double d,
              char *cs, float *fp, double *dp,
              int nums[],
              struct Point *pp, union Cell *up,
              enum Mode m, class Widget *wp) {
    char local_c = c;
    float local_f = f;
    double local_d = d;
    char *local_cs = cs;
    float *local_fp = fp;
    double *local_dp = dp;
    log_event(local_cs);     /* call resolved via the prototype (forward call) */
}

void log_event(char *tag) {  /* definition: PROCEDURE_DEFINITION */
    return;
}

int main() {
    char ch = 'x';
    float fl = 1.5;
    double db = 2.5;
    char *chp = &ch;
    float *flp = &fl;
    double *dbp = &db;
    int values[4];
    struct Point pt;
    union Cell cell;
    enum Mode md = MODE_A;
    class Widget w;

    take_all(ch, fl, db, chp, flp, dbp, values, &pt, &cell, md, &w);
    log_event("startup");    /* call resolved via the real definition */

    return 0;
}
