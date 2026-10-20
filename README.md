# THECompiler

## Team

- Anjan — 24114012
- Dhruv — 24115057
- Keshav — 24114048
- Mayank — 24115101

---

## Overview

A compiler front end for a C/C++-inspired source language, built with
**Flex** (lexer) and **Bison/YACC** (parser) in C++17. It has three tools,
one per stage:

| Stage | Tool | Input → Output |
|:------|:-----|:---------------|
| 1. Lexical analysis | `lexer_app` | source → token table |
| 2. Syntax analysis + semantic labelling | `syntax_analyzer` | source → 4-column report (lexeme, token, type, scope) or syntax errors |
| 3. Type checking + intermediate code generation | `ir_generator` | source → **three-address code (3AC) in a `.ir` file**, or lexical/syntax/semantic errors |

Every tool exits with `0` for a valid program and `1` on an error.

---

## Pipeline

```
                 ┌─────────────┐  tokens  ┌──────────────────────────┐
  prog.c  ─────► │ Flex lexer  │ ───────► │ Bison parser (LALR(1),   │
                 │ ir_lexer.l  │ ◄─────── │ 0 conflicts)  ir.y       │
                 └─────────────┘ typedef  └────────────┬─────────────┘
                                 lookups               │ grammar actions
                     ┌─────────────────────────────────┼──────────────────────┐
                     ▼                                 ▼                      ▼
          ┌────────────────────┐         ┌──────────────────────┐  ┌────────────────────┐
          │ ScopedSymbolTable  │         │ Type checker         │  │ 3AC generator      │
          │ scopes, shadowing, │ ◄─────► │ type_check.h         │─►│ ir_gen.h: quads,   │
          │ overload sets      │         │ conversions, errors  │  │ backpatching, .data│
          └────────────────────┘         └──────────────────────┘  └─────────┬──────────┘
                                                                             ▼
                                                                         prog.ir
```

All three jobs happen in **one pass** over the source: there is no syntax
tree. Each grammar action checks the types of its operands first and only
then emits code; any semantic error stops the IR file from being written.

---

## Intermediate Code Generation (3AC)

### Usage

```bash
make ir                                 # build ir_generator
./ir_generator prog.c                   # writes prog.ir next to prog.c
./ir_generator prog.c -o out/prog.ir    # choose the output path
```

On success it prints `IR written to <path>`. On an error it prints the
messages to stderr, exits with `1`, and writes no file:

```
Semantic errors found:
Semantic Error at line 4: 'b' undeclared
```

### Example

```c
int fact(int n) {
    if (n <= 1) return 1;
    return n * fact(n - 1);
}
```

```
.data

.text
func_begin fact@i
  params: n:int
  0: if n <= 1 goto 2
  1: goto 3
  2: return 1
  3: t1 = n - 1
  4: param t1
  5: t2 = call fact@i, 1
  6: t3 = n * t2
  7: return t3
func_end fact@i
```

### Output format

An `.ir` file has up to three sections:

| Section | Contents |
|:--------|:---------|
| `.types` | Struct/union layouts: `struct Point: size 8 { x:int @0, y:int @4 }` (only when the program has any) |
| `.data` | Globals, `static` variables and string literals: `name: type (size) = init` |
| `.text` | One `func_begin` … `func_end` block per function, listing its `params` and `locals`, then numbered instructions |

Instructions are numbered across the whole file, and jump targets are
instruction numbers. Temporaries `t1, t2, …` restart in each function.

| Instruction | Meaning |
|:------------|:--------|
| `x = y op z`, `x = -y`, `x = ~y` | Arithmetic, bitwise, shift |
| `x = (float) y` | Explicit type conversion (int ↔ float, float ↔ double) |
| `x = &y`, `x = *p`, `*p = y` | Address-of, load through pointer, store through pointer |
| `x = a[8]`, `a[8] = y` | Load/store the object **8 bytes** into variable `a` |
| `goto 7`, `if x < y goto 7`, `if x goto 7` | Jumps |
| `param x`, `t = call f@ii, 2`, `t = icall fp, 2` | Calls (direct and through a function pointer) |
| `return x`, `t = new 16`, `delete p` | Return, allocate, free |

A `.strN` operand is the address of a string literal, and `&f@ii` is the
address of a function.

### How it works

- **Backpatching** (Dragon book §6.6–6.7): conditions are compiled to jumps
  whose targets are filled in once known, giving short-circuit `&&` / `||`
  and all loops, `switch` and `goto` without a syntax tree.
- **Name mangling:** every function except `main` is named
  `name@<parameter codes>` (`add@ii`, `add@ff`), which is what makes
  overloading possible. Codes: `i` int, `c` char, `f` float, `d` double,
  `P` pointer, `R` reference, `S5Point` struct Point, `v` no parameters.
- **Memory layout:** structs get real offsets (each member aligned to its
  own size); arrays are row-major; pointer arithmetic is scaled by the
  element size.
- **Constant folding** of integer expressions, so `2 * 3 + 4` becomes `10`.

### Features

All 24 features of the specification are translated, each with a test in
`tests/ir/valid/` whose expected IR was written by hand:

| Basic | Advanced |
|:------|:---------|
| Arithmetic & logical operators (`01`) | Recursion (`14`) |
| `if` / `if-else` (`02`) | Dynamic memory: `new`, `delete`, `malloc`, `free` (`15`) |
| `for` loop (`03`) | Function pointers (`16`) |
| `while` loop (`04`) | Command-line input `argc` / `argv` (`17`) |
| `do-while` loop (`05`) | `typedef` (`18`) |
| `switch` / `case` / `default` (`06`) | References (`19`) |
| Arrays, int and char (`07`) | `enum`, `union` (`20`) |
| Pointers (`08`) | `until` loop (`21`) |
| Structures (`09`) | Multi-level pointers (`22`) |
| `printf` / `scanf` (`10`) | Multi-dimensional arrays (`23`) |
| Function calls with arguments (`11`) | Function overloading (`24`) |
| `goto`, `break`, `continue` (`12`) | Short-circuit boolean values (`25`) |
| `static` (`13`) | Implicit type conversions (`26`) |

### Type checking

Reported as `Semantic Error at line N: …` (tests in `tests/ir/invalid/`):

- undeclared or redeclared names
- assignment to a non-lvalue, or with an incompatible type
- invalid operand types (e.g. `%` on a float)
- wrong argument count or types; ambiguous or missing overload; overloads
  differing only in return type
- `return` not matching the function's return type
- function-pointer signature mismatch
- invalid `*`, `.`, `->`, `[]`
- non-constant array size or global initializer
- `break` / `continue` outside a loop; non-integer `switch`; duplicate `case`
- undefined or duplicate labels
- invalid reference binding

---

## Syntax Analysis (stage 2)

`syntax_analyzer` parses the program and labels every identifier with its
type, modifier, role and scope.

```c
int add(int a, int b) { return a + b; }
```

```
Lexeme              Token_Name          Token_Type                              Scope
------------------------------------------------------------------------------------------
int                 T_INT               T_INT                                   global
add                 T_IDENTIFIER        FUNCTION_DEFINITION(returns:INT)        global
(                   T_LPAREN            T_LPAREN                                global
int                 T_INT               T_INT                                   global
a                   T_IDENTIFIER        INT_PARAMETER                           add
...
```

Design highlights:

- **Scope labeling** — scopes are named hierarchically (`main`,
  `main.block1`, `struct:Point`, `class:Shape.getArea`).
- **Error recovery** — `error ';'` and `error '}'` productions let several
  syntax errors be reported in one run.
- **Zero conflicts** — dangling `else` is resolved with Bison precedence.

A per-feature status of the labelling stage, including its known labelling
defects, is in `FEATURE_PROGRESS.md`.

---

## How to Build & Run

### Prerequisites

- **Bison** (3.x)
- **Flex**
- **g++** with C++17 support

### Build

```bash
make                 # build all three tools
make lexer           # lexer_app only
make parser          # syntax_analyzer only
make ir              # ir_generator only
```

### Run

```bash
./lexer_app tests/lexer/valid/valid_basic.c
./syntax_analyzer tests/parser/valid/syntax_valid_basic.c
./ir_generator tests/ir/valid/14_recursion.c && cat tests/ir/valid/14_recursion.ir
```

### Run tests

```bash
make test            # all suites
./run.sh             # all suites
./run.sh --ir        # one suite: --lexer, --parser or --ir (flags combine)
./run.sh --ir -v     # verbose: also print each test's output
```

**Windows (PowerShell):** `.\run_tests.ps1 -Parser`, or the scripts in
`scripts\*.ps1` (lexer and parser suites).

### Clean

```bash
make clean
```

---

## Test Suite

| Suite | Valid | Invalid | Checked against |
|:------|:-----:|:-------:|:----------------|
| Lexer (`tests/lexer/`) | 21 | 14 | expected token tables / error messages |
| Parser (`tests/parser/`) | 38 | 17 | expected 4-column reports / syntax errors |
| IR (`tests/ir/`) | 27 | 15 | hand-written expected `.ir` / semantic errors |

For an IR test, `tests/ir/valid/<name>.c` must produce exactly
`tests/ir/expected/valid/<name>.ir`, and `tests/ir/invalid/<name>.c` must
fail with exactly `tests/ir/expected/invalid/<name>.txt`. To add a test,
add both files; the runner picks them up automatically.

---

## Project Structure

```
THECompiler/
├── Makefile                    Root orchestrator (lexer, parser, ir, test)
├── Makefile.lexer              Builds lexer_app
├── Makefile.parser             Builds syntax_analyzer
├── Makefile.ir                 Builds ir_generator
├── run.sh                      Unified test runner (bash)
├── run_tests.ps1               Unified test runner (PowerShell)
├── README.md
├── FEATURE_PROGRESS.md         Per-feature status for every stage
├── scripts/
│   ├── run_lexer_tests.sh / .ps1
│   ├── run_parser_tests.sh / .ps1
│   └── run_ir_tests.sh
├── src/
│   ├── lexer/                  Stage 1: standalone lexer
│   │   ├── lexer.l
│   │   ├── tokens.h
│   │   └── symbol_table.h
│   ├── parser/                 Stage 2: syntax analyzer
│   │   ├── parser.y
│   │   ├── parser_lexer.l
│   │   ├── common.h
│   │   ├── scoped_symbol_table.h
│   │   └── semantic_types.h
│   └── ir/                     Stage 3: type checker + IR generator
│       ├── ir.y                    Grammar, declarations, statements, main()
│       ├── ir_lexer.l              Lexer with typedef-name feedback
│       ├── type_check.h            Type checking + expression translation
│       ├── ir_gen.h                Quads, backpatching, .data, IR printer
│       ├── semantic_types.h        Types, sizes, layouts, name mangling
│       ├── scoped_symbol_table.h   Scopes and function overload sets
│       ├── string_pool.h           Interned lexemes
│       └── common.h                TokenRecord
└── tests/
    ├── lexer/   { valid, invalid, expected }
    ├── parser/  { valid, invalid, expected }
    └── ir/      { valid, invalid, expected/{valid, invalid} }
```

---

## Language Notes and Limitations

- No C-style casts, `sizeof`, comma operator or preprocessor (`#include`);
  `printf`, `scanf`, `malloc` and `free` are built in instead.
- Floating-point literals have type `float` (the language has no suffixes).
- Classes are excluded by the specification: they parse in the syntax
  analyzer, but member functions and `this` are rejected by `ir_generator`.
- `typedef` names are usable as types in `ir_generator` (the lexer consults
  the symbol table); the stage-2 `syntax_analyzer` still rejects them.
- Lexical errors are fatal — unterminated strings, invalid characters, etc.
  stop analysis immediately.
- **Known issue (stage 2):** `src/parser/parser_lexer.l` rejects some char
  literals (`'n'`, `'\n'`, `'\0'`), which fails one parser test
  (`syntax_valid_pointers_arrays.c`). The IR lexer has the fix.
