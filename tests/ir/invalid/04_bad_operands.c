/* TYPE CHECK — operand types: % and shifts need integers, * needs numbers. */
int main() {
    int i = 4;
    float f = 1.5;
    int *p;
    i = f % 2;
    i = p * 2;
    i = i << f;
    return i;
}
