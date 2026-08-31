int main() {
    int x = 0;
    /* Invalid standalone until loop: missing condition parentheses */
    until x > 10 {
        x++;
    }
    return 0;
}
