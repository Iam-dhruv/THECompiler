/* FEATURE 22 — multi-level pointers.
 * Pointer depth is tracked to any level. Each * peels one level: **pp loads
 * *pp into a temp and dereferences that. Every pointer is 8 bytes, so
 * char** arithmetic steps by 8 while char* steps by 1. */
int main() {
    int x = 1;
    int *p = &x;
    int **pp = &p;
    int ***ppp = &pp;
    **pp = 5;
    x = ***ppp + 1;
    char *s = "ab";
    char **ps = &s;
    *ps = *ps + 1;
    return **pp;
}
