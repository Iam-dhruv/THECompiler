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
- **Function overloading & Pareto dominance:** candidates are resolved from
  their arguments; ties among viable candidates are broken using C++-style
  Pareto dominance (a candidate must be strictly better on at least one
  argument and no worse on any; otherwise it is ambiguous).
- **Memory layout:** structs get real offsets (each member aligned to its
  own size); arrays are row-major; pointer arithmetic is scaled by the
  element size.
- **Constant folding** of integer expressions, so `2 * 3 + 4` becomes `10`.

### Features

All 30 IR test cases (covering the full specification and edge cases) are
translated, each with a test in `tests/ir/valid/` whose expected IR was
written by hand:

| Basic | Advanced |
|:------|:---------|
| Minimal program (`00`) | Recursion (`14`) |
| Arithmetic & logical operators (`01`) | Dynamic memory: `new`, `delete`, `malloc`, `free` (`15`) |
| `if` / `if-else` (`02`) | Function pointers (`16`) |
| `for` loop (`03`) | Command-line input `argc` / `argv` (`17`) |
| `while` loop (`04`) | `typedef` (`18`) |
| `do-while` loop (`05`) | References (`19`) |
| `switch` / `case` / `default` (`06`) | `enum`, `union` (`20`) |
| Arrays, int and char (`07`) | `until` loop (`21`) |
| Pointers (`08`) | Multi-level pointers (`22`) |
| Structures (`09`) | Multi-dimensional arrays (`23`) |
| `printf` / `scanf` (`10`) | Function overloading with Pareto dominance (`24`) |
| Function calls with arguments (`11`) | Short-circuit boolean values (`25`) |
| `goto`, `break`, `continue` (`12`) | Implicit type conversions (`26`) |
| `static` (`13`) | Pointer to function pointer (`27`) |
| | Function pointer arrays (`28`) |
| | Reference returns (`29`) |

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
| Parser (`tests/parser/`) | 37 | 17 | expected 4-column reports / syntax errors |
| IR (`tests/ir/`) | 30 | 17 | hand-written expected `.ir` / semantic errors |

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

## Language Notes and Differences from the C Standard

THECompiler compiles a C/C++ hybrid dialect designed for single-pass compilation and intermediate code generation. While largely compatible with standard C syntax, it deliberately introduces modern C++ features, custom constructs, and excludes several complex C constructs.

### 1. C++ Features Adopted (Not present in ISO C)

- **Function Overloading & Name Mangling:** Functions can share the same identifier if their parameter signatures differ (`add(int, int)` vs `add(float, float)`). Symbols are mangled (`name@<param_codes>`), and calls are resolved using C++-style **Pareto dominance** ranking.
- **Reference Types (`&`):** Supports lvalue references (`int &r = x;`) in local variables, function parameters, and function return types. References are implemented as immutable address constants under the hood.
- **C++ Memory Management:** In addition to standard `malloc()` and `free()`, the grammar supports `new T`, `new T[size]`, `delete p`, and `delete[] arr` as dedicated keywords emitting 3AC allocation instructions.
- **Class and OOP Constructs (Parser Stage):** `class`, access specifiers (`public:`, `private:`, `protected:`), and `this` are recognized by the parser. 
### 2. Custom Language Extensions

- **`until` Loops:** A first-class looping construct acting as the logical inversion of `while`:
  - `until (cond) { ... }` — loops while `cond` evaluates to false (terminates when `cond` becomes true).
  - `do { ... } until (cond);` — executes the body at least once, repeating until `cond` becomes true.

### 3. Excluded C Standard Features

- **No Preprocessor (`#`):** No `#include`, `#define`, `#ifdef`, or macro expansion. The `#` character is treated as a lexical error.
- **Built-in Standard Library:** Because `#include <stdio.h>` and `<stdlib.h>` are absent, essential functions (`printf`, `scanf`, `malloc`, `free`) are recognized directly by the compiler as undeclared built-ins.
- **No C-Style Casts:** Explicit casts of the form `(type)expr` are excluded from the grammar to eliminate grammar ambiguities with parenthesized expressions in single-pass parsing without ASTs. Type conversions occur implicitly during assignment, argument passing, and arithmetic.
- **No `sizeof` Operator:** Sizing is handled internally by the compiler during type layout.
- **No Comma Operator:** Commas are only recognized as delimiters in argument lists, parameter lists, and declarations; they cannot be used to sequence expressions (`x = (a, b)`).
- **No Variadic Prototype Declarations (`...`):** User-defined functions cannot declare variable-argument ellipses. Only the built-ins `printf` and `scanf` accept arbitrary argument counts.

### 4. Semantic & Lexical Deviations from ISO C (C99/C11)

| Feature | Standard C (ISO C99/C11) | THECompiler | Reason / Design Decision |
| :--- | :--- | :--- | :--- |
| **Floating-Point Literals** | Type `double` by default; requires `f`/`F` suffix for `float`. | Always type `float`; suffixes (`f`, `d`, `L`) are not supported. | Simplifies literal classification without numeric suffixes. |
| **Non-Decimal Literals** | Supports octal (`0777`), C99 hex floats (`0x1.fp3`), and binary (`0b101` in C23/GCC). | Only standard decimal integers, decimal floats, and hex integers (`0x...`) are accepted. Octal and binary are rejected. | Prevents silent bugs from accidental leading zeros (e.g. `08` / `007`). |
| **Format String Validation** | Often checked via non-standard compiler extensions (`gcc -Wformat`). | Format specifiers are not validated at compile time. | Per C11 §7.21.6.1p9, format mismatches are runtime undefined behavior, not translation errors. |
| **Lexical Errors** | May recover or attempt warning. | All lexical errors (malformed exponents, stray dots, unterminated strings/chars) are immediately fatal. | Prevents corrupted tokens from causing misleading syntax errors downstream. |
| **Static Storage Local Variables** | Preserves state across calls; lives in `.data`. | Preserves state; renamed as `<function>.<name>` in `.data` and initialized at compile time without re-entry overhead. | Guarantees zero runtime initialization cost inside the function body. |
| **Typedef Usability** | Globally and locally scoped aliases immediately usable anywhere in standard C. | Stage 2 (`syntax_analyzer`) labels typedef names; Stage 4 (`ir_generator`) feeds typedef names back from the symbol table to the lexer as `T_TYPE_NAME`. | Overcomes the classic typedef-name problem in single-pass parsing. |
