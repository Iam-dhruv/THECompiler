/* TYPE CHECK — every goto needs a label in the same function; labels are unique. */
int main() {
    int x = 0;
    goto missing;
again:
    x = x + 1;
again:
    return x;
}
