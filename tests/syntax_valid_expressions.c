int compute(int a, int b) {
    int arr[10];
    int *p;
    int i;
    int result;

    arr[0] = a;
    p = &arr[0];
    *p = b;

    i = 0;
    result = (a + b) * 2 - (a / (b + 1)) % 3;

    result = (a > b) ? a : b;

    result = (a == b) && (a != 0) || (b <= 10);

    result = (a & b) | (a ^ b) & ~b;

    result = a << 2 >> 1;

    i++;
    i--;
    ++i;
    --i;

    result += 1;
    result -= 1;
    result *= 2;
    result /= 2;
    result %= 3;
    result &= 0xF;
    result |= 0x1;
    result ^= 0x2;
    result <<= 1;
    result >>= 1;

    return result;
}

int main() {
    int r;
    r = compute(3, 4);
    return r;
}
