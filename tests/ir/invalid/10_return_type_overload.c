/* TYPE CHECK — overloads may not differ only in return type; a return
 * statement must match its function's return type. */
int ambiguous(int n);
float ambiguous(int n);
void nothing() { return 1; }
int value() { return; }
int main() {
    return 0;
}
