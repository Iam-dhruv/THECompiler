/* TYPE CHECK — redeclaring a name in the same scope (an inner block may shadow it). */
int main() {
    int x = 1;
    {
        int x = 2;
    }
    float x;
    return x;
}
