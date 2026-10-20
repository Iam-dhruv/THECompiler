/* TYPE CHECK — switch needs an integer operand; case labels must be
 * distinct integer constants. */
int main() {
    int x = 2;
    float f = 1.5;
    switch (f) {
        case 1: x = 1;
    }
    switch (x) {
        case 1: x = 2;
        case 1: x = 3;
        case x: x = 4;
    }
    return x;
}
