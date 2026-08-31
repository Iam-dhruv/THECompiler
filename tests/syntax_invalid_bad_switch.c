int main() {
    int x = 1;
    /* Syntax Error: switch missing condition expression */
    switch {
        case 1:
            x = 2;
            break;
    }
    return x;
}
