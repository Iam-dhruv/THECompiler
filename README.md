# THECompiler

## Students

- Anjan - 24114012
- Dhruv - 24115057
- Keshav - 24114048
- Mayank - 24115101

A simple lexical analyzer built with Flex/C++ for a small source language inspired by C and C++. It reads a source file, tokenizes it, and produces a token stream table with lexemes and token names. It also detects lexical errors and writes them to an error log.

## What this analyzer does

The lexer scans source code and groups characters into meaningful tokens such as:

- Keywords: if, else, for, while, do, return, int, float, char, etc.
- Identifiers
- Integer literals and floating-point literals
- Character and string literals
- Operators and punctuation
- Comments and whitespace handling

If the source is valid, the analyzer prints a two-column table:

Lexeme                      Token

int                         T_INT
main                        T_IDENTIFIER
(                           T_LPAREN

If the source contains lexical errors, it records and reports the issues instead of producing a complete valid token stream.

## Project structure

- src/lexer.l: Flex lexer specification
- src/lex.yy.c: generated C source from Flex
- src/tokens.h: token definitions
- src/symbol_table.h: symbol table implementation
- tests/: valid and invalid programs used for checking the lexer
- Makefile: builds the lexer executable
- run.sh: runs the lexer across all test files
- run_tests.ps1: Windows PowerShell test runner
- out/: output directory for generated token streams and error logs

## Supported language features

This analyzer is intentionally a subset of C/C++ and is designed for coursework. It supports:

- Arithmetic, relational, logical, bitwise, and assignment operators
- Control-flow keywords such as if, else, for, while, switch, case, default, break, continue
- Type keywords such as int, char, float, double, void, static, struct, enum, class, etc.
- String and character literals with escape handling
- Block comments and line comments
- Basic identifier rules and symbol table tracking

## How to build

### Linux/macOS

```bash
git clone https://github.com/Iam-dhruv/THECompiler
cd THECompiler
make
```

### Windows

Use a terminal with Flex and g++ available, then run:

```powershell
g++ -std=c++17 -Wno-register .\src\lex.yy.c -o .\lexer_app.exe
```

Or simply use the existing project setup if Flex is installed and the binary is already generated.

## How to run

### Run a single file

```bash
./lexer_app tests/valid_basic.c
```

This generates output files in the out/ directory such as:

- out/token_stream_valid_basic.txt
- out/symbol_table_valid_basic.txt
- out/error_log_valid_basic.txt

### Run all test files

```bash
./run.sh ./lexer_app
```

On Windows PowerShell:

```powershell
.\run_tests.ps1
```

## How to run on another device

1. Install the required tools:
   - Flex
   - g++ or a C++ compiler
   - Git
2. Clone the repository:

```bash
git clone https://github.com/Iam-dhruv/THECompiler.git
cd THECompiler
```

3. Build the lexer:

```bash
make
```

4. Run a sample file:

```bash
./lexer_app tests/valid_basic.c
```

5. Optionally run the full suite:

```bash
./run.sh ./lexer_app
```

## Important differences from standard C/C++

This lexer is not a full C or C++ compiler. It is a simplified lexical analyzer designed for learning and coursework. Some key differences are:

1. It is a lexical subset, not a full parser.
   - It recognizes many common tokens but does not implement all of C/C++ grammar.

2. It rejects some invalid numeric forms as lexical errors.
   - Leading-zero octal literals like 0123 are flagged as invalid.
   - Malformed scientific notation is rejected.

3. It is stricter with strings and chars.
   - Unterminated strings and char literals are reported as lexical errors.
   - Unknown escape sequences inside strings are warned about and handled.

4. It supports a custom mix of keywords.
   - Some entries are included because they are useful in the course project, even if they are not part of a minimal C subset.
   - Example: tokens like until, friend, or other extended educational constructs are included in this project.

5. It does not implement preprocessing, macros, include handling, or full type-checking.
   - Standard C/C++ features such as header inclusion, preprocessor directives, and complex templates are outside the scope of this project.

6. The output format is intentionally simplified.
   - It prints a token table and logs lexical errors rather than producing a full compiler-style AST or symbol analysis.

## Example output

Valid input:

```c
int main() {
    int x = 10;
    return x;
}
```

Output (simplified):

```text
Lexeme                      Token

int                         T_INT
main                        T_IDENTIFIER
(                           T_LPAREN
)
```

Invalid input example:

```c
char s[] = "hello;
```

Output:

```text
Error: unterminated string literal starting at line 1
```

## Summary

This project gives a practical introduction to lexical analysis using Flex. It is a focused implementation that demonstrates how a compiler front-end tokenizes source code, recognizes valid tokens, and reports lexical errors clearly.
