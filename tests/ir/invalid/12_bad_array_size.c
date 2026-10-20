/* TYPE CHECK — an array extent must be a positive integer constant, and a
 * global initializer must be a constant. */
int n = 4;
int bad[n];
int zero[0];
int copy = n;
int main() {
    int local[n];
    return 0;
}
