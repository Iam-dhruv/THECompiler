/* FEATURE 17 — command-line input.
 * main(int argc, char *argv[]): an array parameter decays to a pointer, so
 * argv is char**. Indexing a pointer adds the scaled index and then
 * dereferences: argv[i] is t1 = i * 8, t2 = argv + t1, t3 = *t2. */
void show(int n, char *list[]) {
    for (int i = 0; i < n; i++) {
        printf("%s\n", list[i]);
    }
}
int main(int argc, char *argv[]) {
    if (argc > 1) {
        printf("%s\n", argv[1]);
    }
    show(argc, argv);
    return 0;
}
