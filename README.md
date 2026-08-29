# THECompiler

## Students

- Anjan - 24114012
- Dhruv - 24115057
- Keshav - 24114048
- Mayank - 24115101

A compiler front-end for a small source language inspired by C and C++,
built in two stages:

- **Assignment 1 — Lexical Analyzer** (Flex/C++): tokenizes source code and
  produces a token stream table, a symbol table, and a lexical error log.
- **Assignment 2 — Syntax Analyzer** (Bison/YACC + Flex): parses the token
  stream against a formal grammar and either confirms the program is
  syntactically valid or reports syntax errors.

Both stages operate on the same source language and share the same token
set. Each is a separate, independently buildable component (`lexer_app` and
`syntax_analyzer`).

---

## Assignment 1 — Lexical Analyzer

A simple lexical analyzer built with Flex/C++. It reads a source file,
tokenizes it, and produces a token stream table with lexemes and token
names. It also detects lexical errors and writes them to an error log.

### What this analyzer does

The lexer scans source code and groups characters into meaningful tokens
such as:

- Keywords: if, else, for, while, do, return, int, float, char, etc.
- Identifiers
- Integer literals and floating-point literals
- Character and string literals
- Operators and punctuation
- Comments and whitespace handling

If the source is valid, the analyzer prints a two-column table:

```
Lexeme                      Token

int                         T_INT
main                        T_IDENTIFIER
(                           T_LPAREN
```

If the source contains lexical errors, it records and reports the issues
instead of producing a complete valid token stream.

### Project structure

- `src/lexer.l` — Flex lexer specification
- `src/lex.yy.c` — generated C source from Flex
- `src/tokens.h` — token definitions
- `src/symbol_table.h` — symbol table implementation
- `tests/` — valid and invalid programs used for checking the lexer
- `Makefile` — builds the lexer executable (and, as of Assignment 2, the
  syntax analyzer executable — see below)
- `run.sh` — runs the lexer across all test files
- `run_tests.ps1` — Windows PowerShell test runner
- `out/` — output directory for generated token streams and error logs

### Supported language features

This analyzer is intentionally a subset of C/C++ and is designed for
coursework. It supports:

- Arithmetic, relational, logical, bitwise, and assignment operators
- Control-flow keywords such as if, else, for, while, switch, case,
  default, break, continue
- Type keywords such as int, char, float, double, void, static, struct,
  enum, class, etc.
- String and character literals with escape handling
- Block comments and line comments
- Basic identifier rules and symbol table tracking

### How to build

**Linux/macOS**

```bash
git clone https://github.com/Iam-dhruv/THECompiler
cd THECompiler
make
```

**Windows**

Use a terminal with Flex and g++ available, then run:

```powershell
g++ -std=c++17 -Wno-register .\src\lex.yy.c -o .\lexer_app.exe
```

Or simply use the existing project setup if Flex is installed and the
binary is already generated.

### How to run

**Run a single file**

```bash
./lexer_app tests/valid_basic.c
```

This generates output files in the `out/` directory such as:

- `out/token_stream_valid_basic.txt`
- `out/symbol_table_valid_basic.txt`
- `out/error_log_valid_basic.txt`

**Run all test files**

```bash
./run.sh ./lexer_app
```

On Windows PowerShell:

```powershell
.\run_tests.ps1
```

### Important differences from standard C/C++

This lexer is not a full C or C++ compiler. It is a simplified lexical
analyzer designed for learning and coursework. Some key differences are:

1. It is a lexical subset, not a full parser.
   - It recognizes many common tokens but does not implement all of
     C/C++ grammar.
2. It rejects some invalid numeric forms as lexical errors.
   - Leading-zero octal literals like `0123` are flagged as invalid.
   - Malformed scientific notation is rejected.
3. It is stricter with strings and chars.
   - Unterminated strings and char literals are reported as lexical
     errors.
   - Unknown escape sequences inside strings are warned about and
     handled.
4. It supports a custom mix of keywords.
   - Some entries are included because they are useful in the course
     project, even if they are not part of a minimal C subset.
   - Example: tokens like `until`, `friend`, or other extended
     educational constructs are included in this project.
5. It does not implement preprocessing, macros, include handling, or full
   type-checking.
6. The output format is intentionally simplified — it prints a token
   table and logs lexical errors rather than producing a full
   compiler-style AST or symbol analysis.

### Example output

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

---

## Assignment 2 — Syntax Analyzer

A Bison/YACC syntax analyzer for the same source language tokenized by
Assignment 1. It reads a source file, parses it against a hand-written
LALR(1) grammar, and either:

- prints a two-column **Token | Token_Type** table for the whole program,
  if every token in the input forms a syntactically valid program, or
- reports every syntax error found (with line numbers) if it doesn't.

Exit code is `0` on a fully valid program and `1` otherwise (lexical error
or syntax error).

### Project structure (additions over Assignment 1)

- `src/parser.y` — Bison grammar: the syntax rules for the language, plus
  the `main()` driver that prints the token table or the error report.
- `src/parser_lexer.l` — Flex scanner that feeds tokens to the Bison
  parser. A re-implementation of `src/lexer.l`, adapted to return
  Bison-generated token codes and to record every `(lexeme, token_type)`
  pair for the final report table.
- `src/common.h` — shared `TokenRecord` struct used by `parser.y` and
  `parser_lexer.l`.
- `tests/syntax_valid_*.c`, `tests/syntax_invalid_*.c` — syntax-analyzer
  test programs (see below). Kept separate from the Assignment 1
  `tests/valid_*.c` / `tests/invalid_*.c` files, which test lexical
  features only and are not all syntactically valid programs.
- `run_syntax.sh` — runs the syntax analyzer across all
  `tests/syntax_*.c` files.
- `Makefile` — extended with a `syntax_analyzer` build target alongside
  the existing `lexer_app` target.

### How to build

Requires `bison`, `flex`, and a C++17 compiler (`g++`).

```bash
sudo apt-get install bison flex g++   # if not already installed
make
```

`make` now builds both `lexer_app` and `syntax_analyzer` in the project
root.

### How to run

```bash
./syntax_analyzer tests/syntax_valid_basic.c
```

Run the whole syntax-analyzer test suite:

```bash
./run_syntax.sh ./syntax_analyzer
```

### Test cases (`tests/syntax_*.c`)

| File                                    | Purpose                                                         |
|-------------------------------------------|------------------------------------------------------------------|
| `syntax_valid_basic.c`                    | Functions, parameters, declarations, calls, `return`              |
| `syntax_valid_control_flow.c`              | `if`/`else`, `for`, `while`, `do-while`, `do-until`, `switch`/`case`/`default`, `break`, `continue`, `goto`, labels |
| `syntax_valid_oop_features.c`              | `struct`, `enum`, `typedef`, `class` with `public`/`private`, `this`, `new`, `delete` |
| `syntax_valid_expressions.c`               | Full operator precedence chain: arithmetic, relational, logical, bitwise, ternary, all compound-assignment operators, pointers, arrays |
| `syntax_invalid_missing_semicolon.c`       | Missing `;` after a declaration                                   |
| `syntax_invalid_unbalanced_braces.c`       | Missing closing `}`                                                |
| `syntax_invalid_bad_expression.c`          | Empty right-hand side of an assignment (`x = ;`)                   |
| `syntax_invalid_bad_control_flow.c`        | Missing closing `)` in an `if` condition                           |

### Grammar design notes / simplifications

The grammar is a trimmed-down version of the classic ANSI C yacc grammar,
adapted to this project's token set. Some deliberate simplifications,
consistent with the lexer's own stated scope limitations:

- **No C-style casts and no `sizeof`.** Supporting these without ambiguity
  requires knowing whether an identifier inside parentheses names a type —
  the classic "typedef-name problem" — which needs a symbol table wired
  into the lexer (lexer feedback). Out of scope for a syntax-only
  analyzer.
- **`typedef`'d names can't be reused as types.** `typedef int Integer;`
  parses fine as a declaration, but `Integer x;` does not, for the same
  reason as above. Existing keyword-based types (`struct Point p;`,
  `enum Color c;`, `class Shape s;`) work because the leading keyword
  makes them unambiguous.
- **No function pointers, comma operator, or varargs (`...`).**
- **Dangling `else`** is resolved the standard way (attaches to the
  nearest unmatched `if`) using Bison's precedence-based conflict
  resolution — the grammar builds with **zero** shift/reduce or
  reduce/reduce conflicts (verified with `bison -v`).
- **Syntax error recovery**: the grammar includes `error ';'` /
  `error '}'` productions at both the statement and top-level scope, so a
  single malformed statement doesn't necessarily abort analysis of the
  rest of the file — multiple syntax errors can be reported in one run.
- A **lexical** error (illegal character, unterminated string/comment,
  malformed number, etc.) is treated as fatal: analysis stops immediately
  and the lexical error is reported instead of attempting syntax analysis
  on an unreliable token stream.

### Example output

Valid input (`syntax_valid_basic.c`):

```c
int main() {
    int x = 10;
    return x;
}
```

Output (simplified):

```text
Token                       Token_Type
------------------------------------------------
int                         T_INT
main                        T_IDENTIFIER
(                           T_LPAREN
```

Invalid input:

```c
int main() {
    int x = 10
    return x;
}
```

Output:

```text
Syntax errors were found in 'tests/syntax_invalid_missing_semicolon.c':
Syntax Error at line 3: syntax error, unexpected T_RETURN, expecting T_SEMICOLON or T_COMMA
1 syntax error(s) found.
```

---

## How to run on another device

1. Install the required tools:
   - Flex
   - Bison
   - g++ or a C++ compiler
   - Git
2. Clone the repository:

```bash
git clone https://github.com/Iam-dhruv/THECompiler.git
cd THECompiler
```

3. Build both stages:

```bash
make
```

4. Run a sample file through each stage:

```bash
./lexer_app tests/valid_basic.c
./syntax_analyzer tests/syntax_valid_basic.c
```

5. Optionally run the full test suites:

```bash
./run.sh ./lexer_app
./run_syntax.sh ./syntax_analyzer
```

## Summary

This project gives a practical introduction to the front end of a
compiler: Assignment 1 demonstrates lexical analysis with Flex (scanning
source code into tokens, tracking a symbol table, and reporting lexical
errors), and Assignment 2 builds on it with a Bison/YACC syntax analyzer
that validates the token stream against a formal grammar and reports
syntax errors with line numbers.
