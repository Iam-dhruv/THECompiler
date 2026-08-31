# THECompiler — Syntax Analyzer

## Team

- Anjan — 24114012
- Dhruv — 24115057
- Keshav — 24114048
- Mayank — 24115101

---

## Overview

A syntax analyzer and semantic classifier for a C/C++ inspired source
language, built with **Bison/YACC** (parser) and **Flex** (lexer) in C++17.

Given a source file, the analyzer:

1. **Tokenizes** the input via a Flex-generated lexer.
2. **Parses** the token stream against an LALR(1) grammar (zero
   shift/reduce conflicts).
3. **Classifies** every identifier semantically — type, modifier, role,
   and scope — in a single pass using a **scoped symbol table**.
4. **Outputs** a four-column report table (`Lexeme | Token_Name |
   Token_Type | Scope`) if the program is valid, or a list of syntax
   errors with line numbers if it isn't.

Exit code `0` = valid program; `1` = syntax or lexical error.

---

## Architecture

```
┌──────────────┐    tokens    ┌──────────────────┐   classified   ┌──────────────┐
│  Flex Lexer  │ ──────────►  │   Bison Parser   │ ────────────►  │  4-Column    │
│ parser_lexer │   + record   │    parser.y       │    output      │  Report      │
│     .l       │   TokenRecord│  (LALR(1) grammar)│                │  Table       │
└──────────────┘              └────────┬─────────┘                └──────────────┘
                                       │
                                       ▼
                              ┌──────────────────┐
                              │ ScopedSymbolTable │
                              │  (nested scopes,  │
                              │   shadowing,       │
                              │   classification)  │
                              └──────────────────┘
```

### Source Files

```
src/parser/
├── parser.y                 Bison grammar + semantic actions + main()
├── parser_lexer.l           Flex scanner feeding Bison token codes
├── common.h                 TokenRecord struct (lexeme, token_name, token_type, scope)
├── scoped_symbol_table.h    Scope stack with push/pop, insert, lookup, scope labeling
└── semantic_types.h         BaseKind, Role, TypeInfo enums + format_semantic_type()
```

### Key Design Decisions

- **Single-pass classification** — no AST is built. The parser's semantic
  actions classify identifiers inline as they're reduced, using a scoped
  symbol table.
- **Scope labeling** — each scope is named hierarchically
  (e.g. `main`, `main.block1`, `struct:Point`, `class:Shape.getArea`).
  On `pop_scope()`, all tokens in the scope's range are bulk-labeled.
- **Identifier reclassification** — an identifier's `Token_Type` starts as
  `T_IDENTIFIER` and is reclassified based on context:
  `INT_VARIABLE`, `FLOAT_PARAMETER`, `FUNCTION_DEFINITION(returns:INT)`,
  `STRUCT_TAG`, `ENUM_CONSTANT`, `LABEL`, etc.
- **Error recovery** — `error ';'` and `error '}'` productions at both
  statement and top-level scope, allowing multiple syntax errors to be
  reported in one run.
- **Zero conflicts** — the grammar builds with no shift/reduce or
  reduce/reduce conflicts. Dangling `else` is resolved via Bison
  precedence declarations.

---

## Features Implemented

### Basic Features

| Feature | Status | Notes |
|:--------|:------:|:------|
| Arithmetic, relational, logical, bitwise operators | ✅ | Full precedence chain with all compound assignments (`+=`, `<<=`, etc.) |
| `if`/`else` conditionals | ✅ | Braced bodies get nested block scopes |
| `for` / `while` / `do-while` loops | ✅ | Includes `for(;;)` infinite form |
| `switch`/`case`/`default` | ✅ | Braced case bodies are scoped; switch body follows C fallthrough |
| Arrays (`int[]`, `char[]`, multi-dimensional) | ✅ | Classified as `INT_ARRAY`, `CHAR_ARRAY`, etc. |
| Pointers (single and multi-level) | ✅ | `INT_POINTER`, `INT_POINTER_POINTER` |
| Structures (`struct`) | ✅ | `STRUCT_TAG` / `STRUCT_VARIABLE` / `STRUCT_POINTER`; body gets `struct:Name` scope |
| Function definitions, prototypes, and calls | ✅ | `FUNCTION_DEFINITION(returns:INT)`, `FUNCTION_CALL(returns:UNKNOWN)` for undeclared calls |
| `goto`, `break`, `continue`, labels | ✅ | Labels classified as `LABEL` (forward + backward) |
| `static` keyword | ✅ | Parses as storage-class specifier |
| `printf` / `scanf` | ✅ | Resolved as undeclared function calls |

### Advanced Features

| Feature | Status | Notes |
|:--------|:------:|:------|
| Recursive functions | ✅ | Self-calls resolve correctly; mutual recursion via prototypes |
| Dynamic memory (`new`/`delete`) | ✅ | `new int`, `new int[100]`, `delete p`, `delete[] arr` |
| Function pointers | ✅ | `int (*fp)(int,int)` and calls `fp(x,y)` / `(*fp)(x,y)` parse |
| Command-line args (`argc`, `argv`) | ✅ | Parses `int main(int argc, char *argv[])` |
| `typedef` | ✅ | Declarations classified as `TYPEDEF_NAME` |
| References (`&`) | ✅ | `int &ref = x;` and pass-by-reference parameters parse |
| `enum` and `union` | ✅ | `ENUM_TAG`/`UNION_TAG`, `ENUM_CONSTANT`; body scopes `enum:Name` / `union:Name` |
| `until` loop | ✅ | Both forms: `do { } until (c);` and standalone `until (c) { }` |
| Multi-level pointers | ✅ | Parses `**`, `***` to any depth |
| Multi-dimensional arrays | ✅ | Declaration and indexing to any depth |
| Function overloading | ✅ | Multiple declarations with same name parse correctly |

### OOP Features (Optional)

| Feature | Status | Notes |
|:--------|:------:|:------|
| Classes (`class Name { ... }`) | ✅ | `CLASS_TAG`, methods scoped `class:Shape.getArea` |
| Access specifiers (`public`, `private`, `protected`) | ✅ | Labels parse inside class bodies |
| `this`, `new`, `delete` | ✅ | Keywords recognized and parsed |

---

## Example Output

**Valid program:**

```c
int add(int a, int b) {
    int result;
    result = a + b;
    return result;
}
int main() {
    int x = add(3, 4);
    return 0;
}
```

```
Lexeme              Token_Name          Token_Type                              Scope
------------------------------------------------------------------------------------------
int                 T_INT               T_INT                                   global
add                 T_IDENTIFIER        FUNCTION_DEFINITION(returns:INT)        global
(                   T_LPAREN            T_LPAREN                                global
int                 T_INT               T_INT                                   global
a                   T_IDENTIFIER        INT_PARAMETER                           add
,                   T_COMMA             T_COMMA                                 add
int                 T_INT               T_INT                                   add
b                   T_IDENTIFIER        INT_PARAMETER                           add
...
x                   T_IDENTIFIER        INT_VARIABLE                            main
=                   T_ASSIGN            T_ASSIGN                                main
add                 T_IDENTIFIER        FUNCTION_CALL(returns:INT)              main
```

**Invalid program:**

```c
int main() {
    int x = 10
    return x;
}
```

```
Syntax errors were found in 'tests/parser/invalid/syntax_invalid_missing_semicolon.c':
Syntax Error at line 3: syntax error, unexpected T_RETURN, expecting T_SEMICOLON or T_COMMA
1 syntax error(s) found.
```

---

## Test Suite

**All 26 parser tests pass** — 12 valid + 14 invalid.

### Valid Syntax Tests

| Test File | What It Covers |
|:----------|:---------------|
| `syntax_valid_basic.c` | Functions, parameters, declarations, calls, `return` |
| `syntax_valid_control_flow.c` | `if`/`else`, `for`, `while`, `do-while`, `do-until`, `switch`, `break`, `continue`, `goto` |
| `syntax_valid_expressions.c` | Full operator precedence: arithmetic, relational, logical, bitwise, ternary, compound-assignment |
| `syntax_valid_operators_expressions.c` | All operators, pointer arithmetic, cast-style expressions |
| `syntax_valid_composite_types.c` | `struct`, `enum`, `union`, `static`, nested structs, `printf`/`scanf` |
| `syntax_valid_oop_features.c` | `class`, `typedef`, access specifiers, `this`, `new`, `delete` |
| `syntax_valid_pointers_arrays.c` | Single/multi-level pointers, multi-dimensional arrays, pointer-to-pointer |
| `syntax_valid_functions_recursion.c` | Recursive calls, mutual recursion, overloaded declarations, `argc`/`argv` |
| `syntax_valid_advanced.c` | Complex nested scoping, multiple functions, mixed types |
| `syntax_valid_advanced_features.c` | `until` loop (both forms), `new int[n]`, `delete[]`, dynamic allocation |
| `syntax_valid_scoping_edge_cases.c` | Variable shadowing, nested blocks, forward/backward `goto` |
| `syntax_valid_type_classification_matrix.c` | Exhaustive type × modifier × role classification coverage |

### Invalid Syntax Tests

| Test File | Error Exercised |
|:----------|:----------------|
| `syntax_invalid_missing_semicolon.c` | Missing `;` after declaration |
| `syntax_invalid_unbalanced_braces.c` | Missing closing `}` |
| `syntax_invalid_unbalanced_parens.c` | Missing closing `)` |
| `syntax_invalid_bad_expression.c` | Empty RHS (`x = ;`) |
| `syntax_invalid_bad_control_flow.c` | Missing `)` in `if` condition |
| `syntax_invalid_bad_struct_decl.c` | Malformed struct body |
| `syntax_invalid_bad_enum_decl.c` | Malformed enum body |
| `syntax_invalid_bad_array_decl.c` | Bad array declaration |
| `syntax_invalid_bad_class_access.c` | Invalid class member access |
| `syntax_invalid_bad_function_ptr.c` | Malformed function pointer |
| `syntax_invalid_bad_reference.c` | Invalid reference usage |
| `syntax_invalid_bad_switch.c` | Malformed switch statement |
| `syntax_invalid_bad_until.c` | `until` without parenthesized condition |
| `syntax_invalid_two_errors.c` | Multiple errors reported in one run (error recovery) |

---

## How to Build & Run

### Prerequisites

- **Bison** (≥ 2.4, ideally 3.x)
- **Flex**
- **g++** (C++17 support)

### Build

```bash
make parser          # build syntax_analyzer only
make                 # build everything
```

### Run

```bash
./syntax_analyzer tests/parser/valid/syntax_valid_basic.c
```

### Run Tests

```bash
# Parser tests only
make test-parser
bash scripts/run_parser_tests.sh

# All tests
make test
bash run.sh
```

**Windows (PowerShell):**

```powershell
.\scripts\run_parser_tests.ps1
.\run_tests.ps1 -Parser
```

### Clean

```bash
make clean
```

---

## Project Structure

```
THECompiler/
├── Makefile                    Root orchestrator
├── Makefile.parser             Builds syntax_analyzer
├── Makefile.lexer              Builds lexer_app
├── run.sh                      Unified test wrapper (bash)
├── run_tests.ps1               Unified test wrapper (PowerShell)
├── scripts/
│   ├── run_parser_tests.sh     Parser test runner (bash)
│   ├── run_parser_tests.ps1    Parser test runner (PowerShell)
│   ├── run_lexer_tests.sh      Lexer test runner (bash)
│   └── run_lexer_tests.ps1     Lexer test runner (PowerShell)
├── src/
│   ├── parser/                 Syntax analyzer sources
│   │   ├── parser.y
│   │   ├── parser_lexer.l
│   │   ├── common.h
│   │   ├── scoped_symbol_table.h
│   │   └── semantic_types.h
│   └── lexer/                  Standalone lexer sources
│       ├── lexer.l
│       ├── tokens.h
│       └── symbol_table.h
└── tests/
    ├── parser/
    │   ├── valid/               12 syntax_valid_*.c files
    │   ├── invalid/             14 syntax_invalid_*.c files
    │   └── expected/
    │       ├── valid/           Expected outputs for valid tests
    │       └── invalid/         Expected outputs for invalid tests
    └── lexer/
        ├── valid/               18 valid_*.c files
        ├── invalid/             13 invalid_*.c files
        └── expected/
            ├── valid/
            └── invalid/
```

---

## Grammar Design Notes

- Trimmed-down ANSI C grammar adapted for this project's token set.
- **No C-style casts or `sizeof`** — avoiding the typedef-name problem
  (would require symbol table feedback into the lexer).
- **`typedef`'d names can't be reused as type specifiers** — `typedef int
  Integer;` parses, but `Integer x;` does not (documented non-goal).
- **Dangling `else`** resolved via Bison precedence (standard approach).
- **Lexical errors are fatal** — unterminated strings, invalid characters,
  etc. immediately abort analysis rather than feeding bad tokens to the
  parser.
