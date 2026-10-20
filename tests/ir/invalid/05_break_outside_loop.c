/* TYPE CHECK — break needs an enclosing loop or switch; continue needs a loop. */
int main() {
    int x = 1;
    break;
    switch (x) {
        case 1: continue;
    }
    return x;
}
