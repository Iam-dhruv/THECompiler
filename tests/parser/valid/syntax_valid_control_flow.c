int classify(int n) {
    int i;
    int result = 0;

    if (n < 0) {
        result = -1;
    } else {
        result = 1;
    }

    for (i = 0; i < n; i++) {
        result += i;
    }

    i = 0;
    while (i < n) {
        i++;
    }

    i = 0;
    do {
        i++;
    } while (i < n);

    i = 0;
    do {
        i++;
    } until (i >= n);

    switch (n) {
        case 0:
            result = 100;
            break;
        case 1:
            result = 200;
            break;
        default:
            continue;
    }

    if (result > 1000)
        goto done;

    return result;

    done:
    return -1;
}
