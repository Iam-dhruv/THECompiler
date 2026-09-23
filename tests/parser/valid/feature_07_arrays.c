/* ============================================================================
 * FEATURE 07: Arrays, integer and char   (Basic Features)
 *
 * SYNTAX CHECKS        Sized declarations, unsized declarations, brace
 *                      initializer lists, indexing as an rvalue and as an
 *                      assignment target, and an array parameter.
 * LABELLING CHECKS     THE POINT OF THIS TEST — the declared identifier must
 *                      carry the right Token_Type:
 *                        numbers  -> INT_ARRAY
 *                        letters  -> CHAR_ARRAY
 *                        data     -> INT_ARRAY   (unsized form)
 *                        values   -> INT_ARRAY_PARAMETER  (in scope `total`)
 *                      Note the modifier replaces _VARIABLE: an array is
 *                      INT_ARRAY, never INT_ARRAY_VARIABLE.
 * NOT A SYNTAX CONCERN Bounds. `numbers[999]` on a 5-element array parses
 *                      happily — there is no index range checking, and the
 *                      declared extent is not even retained in TypeInfo (only
 *                      a boolean is_array), so no later phase could check it
 *                      yet either. Initializer length vs. declared size is
 *                      likewise unchecked.
 * ==========================================================================*/
int total(int values[], int count);

int total(int values[], int count) {
    int i;
    int sum = 0;
    for (i = 0; i < count; i++) {
        sum = sum + values[i];
    }
    return sum;
}

int main() {
    int  numbers[5];
    char letters[16];
    int  data[] = { 1, 2, 3 };
    char word[4] = { 'a', 'b', 'c', 'd' };

    numbers[0] = 10;
    numbers[1] = numbers[0] + 5;
    letters[0] = 'A';
    letters[1] = letters[0];

    /* index by an expression, and out of the declared range (not checked) */
    int i = 2;
    numbers[i + 1] = 7;
    numbers[999]   = 1;

    return total(numbers, 5) + data[0] + word[0];
}
