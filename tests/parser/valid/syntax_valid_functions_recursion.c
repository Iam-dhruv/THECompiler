/* ============================================================================
 * syntax_valid_functions_recursion.c
 * Validates:
 *   - Function prototypes / forward declarations
 *   - Functions with multiple parameters & void returns
 *   - Recursive function calls (factorial, fibonacci, mutual recursion)
 *   - Function overloading declarations & definitions
 *   - main() with command line arguments (argc, argv)
 * ==========================================================================*/

/* Forward declarations / prototypes */
int factorial(int n);
int fibonacci(int n);
void log_message(char *msg);

/* Function overloading (syntactically permitted in grammar) */
int calculate(int x);
int calculate(int x, int y);
float calculate(float f);

int calculate(int x) {
    return x * 2;
}

int calculate(int x, int y) {
    return x + y;
}

/* Recursive function: factorial */
int factorial(int n) {
    if (n <= 1) {
        return 1;
    }
    return n * factorial(n - 1);
}

/* Recursive function: fibonacci */
int fibonacci(int n) {
    if (n <= 0) return 0;
    if (n == 1) return 1;
    return fibonacci(n - 1) + fibonacci(n - 2);
}

void log_message(char *msg) {
    /* Function body with call */
    return;
}

/* Entry point with command line arguments */
int main(int argc, char *argv[]) {
    int f5 = factorial(5);
    int fib7 = fibonacci(7);
    int c1 = calculate(10);
    int c2 = calculate(10, 20);

    log_message("Execution completed");

    return 0;
}
