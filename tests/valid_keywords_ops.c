int main() {
    int a = 10;
    a += 2;
    a -= 1;
    a *= 3;
    a /= 2;
    a %= 3;
    a &= 0xFF;
    a |= 0x01;
    a ^= 0x0F;
    a <<= 1;
    a >>= 1;
    int b = (a == 0) ? 1 : 0;
    int c = (a != b) && (a >= 0) || (b <= 5);
    return 0;
}
