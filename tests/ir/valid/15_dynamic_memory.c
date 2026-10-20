/* FEATURE 15 — dynamic memory allocation.
 * new T allocates sizeof(T) bytes ("t = new 4"); new T[n] allocates
 * n * sizeof(T); delete and delete[] release a pointer. malloc and free are
 * built-in calls; malloc returns void*, which converts to any object
 * pointer. A struct may point to its own (still incomplete) type. */
struct Node { int value; struct Node *next; };
int main() {
    int n = 3;
    int *one = new int;
    int *many = new int[n];
    struct Node *node = new struct Node;
    node->next = 0;
    char *buf = malloc(16);
    *one = 1;
    delete one;
    delete[] many;
    free(buf);
    return n;
}
