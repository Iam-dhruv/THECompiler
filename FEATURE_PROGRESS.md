# Feature Implementation Progress

Status of every feature in the project specification, tracked per compiler stage.

**Last verified:** 2026-09-23 · branch `parser_1` · commit `e55a1b5` + local fix
**Scope note:** this project's current deliverable is **lexical + syntactic
analysis with semantic *labelling*** (identifier classification: type,
modifier, role, scope) — not type checking. Type checking, preprocessing,
and 3AC/x86 codegen are separate, later stages and are tracked here only as
"not started," never as defects.
**How this was produced:** every row was checked by building
`syntax_analyzer`/`lexer_app` and running probe programs through them (cross-
checked against `gcc` where the C standard is the reference), not by reading
`README.md`. Rows that disagree with the README are flagged in the Notes.

---

## Pipeline Stages

| # | Stage | Artifact | State |
|:-:|:------|:---------|:------|
| 1 | **Lexical analysis** | `src/lexer/lexer.l`, `src/parser/parser_lexer.l` | ✅ Complete |
| 2 | **Syntax analysis** | `src/parser/parser.y` (LALR(1), 0 conflicts) | ✅ Complete |
| 3 | **Semantic labelling** | `scoped_symbol_table.h`, `semantic_types.h` | 🟡 Mostly complete — labelling defects below; **type checking is out of scope, not a gap** |
| 4 | **IR generation (3AC)** | — | ❌ Not started (not yet in scope) |
| 5 | **Optimization** | — | ❌ Not started (not yet in scope) |
| 6 | **x86 code generation** | — | ❌ Not started (not yet in scope) |

**Legend:** ✅ done · 🟡 partial · ❌ not started

> **Note for later stages, not a current defect.** The parser builds no AST —
> it labels identifiers inline in grammar actions during a single pass. When
> 3AC generation begins, control-flow statements will need something
> revisitable for backpatching (a tree, or an explicit statement list), which
> the current single-pass design doesn't produce. Flagged here so it isn't a
> surprise when Stage 4 starts; it is **not** part of the current deliverable.

---

## Basic Features (labelling stage)

| Feature | Lex | Parse | Label | Notes |
|:--------|:---:|:-----:|:-----:|:------|
| Arithmetic & logical operators | ✅ | ✅ | ✅ | Full precedence chain incl. bitwise, ternary, all compound assigns. |
| `if`-`else` | ✅ | ✅ | ✅ | Dangling-else resolved by `%nonassoc IFX`/`T_ELSE` precedence. |
| `for` loop | ✅ | ✅ | ✅ | Incl. `for(;;)`; init may be a declaration. |
| `while` loop | ✅ | ✅ | ✅ | |
| `do-while` loop | ✅ | ✅ | ✅ | |
| `switch` / `case` / `default` | ✅ | ✅ | ✅ | C fallthrough semantics; braced case bodies scoped. |
| Array (integer and char) | ✅ | ✅ | ✅ | Labelled `INT_ARRAY` / `CHAR_ARRAY`. Dimensions/extents aren't retained in `TypeInfo` — fine for labelling, will matter once IR needs sizes. |
| Pointers | ✅ | ✅ | 🟡 | `pointer_depth` tracked correctly; **display defect** — see Multi-level pointers below. |
| Structure | ✅ | ✅ | 🟡 | `STRUCT_TAG`/`STRUCT_VARIABLE`/`STRUCT_POINTER` labelled, body scoped `struct:Name`. Members after `.`/`->` are intentionally left unlabelled (documented in `parser.y`'s header comment) — no per-struct member namespace yet. |
| `printf` and `scanf` | ✅ | ✅ | ✅ | **Supported at this stage.** Calls with any number of arguments parse (`argument_expr_list` is unbounded) and label as `FUNCTION_CALL(returns:UNKNOWN)` — correct, since without a preprocessor `printf` is never declared and is legitimately an undeclared call. Verified: `printf("%d %s %f\n", n, "txt", 1.5)` parses. |
| Function call with arguments | ✅ | ✅ | ✅ | `FUNCTION_DEFINITION` / `_PROTOTYPE` / `_CALL(returns:T)`. Arity/type checking against the declaration is a type-checking concern, out of scope. |
| `goto`, `break`, `continue` | ✅ | ✅ | ✅ | Labels classified `LABEL`, forward and backward. |
| `static` keyword | ✅ | ✅ | ❌ | **Defect.** Parses, then discarded — `TypeInfo` has no `is_static` field, so `static int c;` labels identically to `int c;`. |

---

## Advanced Features (labelling stage)

| Feature | Lex | Parse | Label | Notes |
|:--------|:---:|:-----:|:-----:|:------|
| Recursive function call | ✅ | ✅ | ✅ | Verified: self-call inside a factorial function resolves to `FUNCTION_CALL(returns:INT)`. |
| Dynamic memory allocation | ✅ | ✅ | ✅ | `new T`, `new T[n]`, `delete p`, `delete[] arr` are dedicated grammar productions. `malloc`/`free` also work, as ordinary undeclared calls. |
| Function pointer | ✅ | ✅ | ❌ | **Defect — README overstates this.** `int (*fp)(int,int);` parses, but is labelled **`FUNCTION_PROTOTYPE(returns:INT)`** — indistinguishable from a real function declaration. `parser.y`'s own header comment states "No function-pointer declarators"; there is no declarator form or `TypeInfo` bit for "pointer to function." |
| Command line input | ✅ | ✅ | 🟡 | `int main(int argc, char *argv[])` parses; `argc` → `INT_PARAMETER` correctly. **Defect:** `argv` → `CHAR_ARRAY_PARAMETER`, losing the pointer — `format_semantic_type()` ([semantic_types.h:60](src/parser/semantic_types.h#L60)) checks `is_array` before `pointer_depth`, so `char *x[]` can never render as pointer. |
| `typedef` | ✅ | 🟡 | 🟡 | **Defect.** `typedef int Integer;` parses and labels `TYPEDEF_NAME`, but the name **cannot be used afterward** — `Integer x;` is a syntax error. Classic typedef-name problem: needs the lexer to consult the symbol table to know `Integer` is a type. A typedef that can't be used isn't a usable feature yet. |
| Reference | ✅ | ✅ | ❌ | **Defect.** `int &r = x;` parses, but [parser.y:382](src/parser/parser.y#L382)'s `T_BIT_AND direct_declarator` rule drops the `&` — `r` labels as a plain `INT_VARIABLE`, identical to a value. No reference bit in `TypeInfo`. |
| `enum`, `union` | ✅ | ✅ | ✅ | `ENUM_TAG`/`UNION_TAG`, `ENUM_CONSTANT` (incl. `= value`), bodies scoped `enum:Name`/`union:Name`. |
| `until` loop | ✅ | ✅ | ✅ | Both forms verified: `do { } until (c);` and `until (c) { }`. Project's own non-C extension. |
| Multi-level pointers | ✅ | ✅ | 🟡 | **Display defect only** — data is correct, rendering isn't. `pointer_depth` is stored correctly for any depth, but `format_semantic_type()` ([semantic_types.h:62](src/parser/semantic_types.h#L62)) maps every depth ≥ 2 to `_POINTER_POINTER`, so `int****` and `int**` render identically. |
| Multi-dimensional arrays | ✅ | ✅ | 🟡 | `int m[2][3][4];` and `grid[1][2]` parse and label as a flat `INT_ARRAY`. Rank/extents aren't retained — acceptable for labelling, will need to be added before IR. |
| Function overloading | ✅ | ✅ | ❌ | **Defect — README overstates this.** Both `int f(int)` and `float f(float)` parse, but a scope's symbol table ([scoped_symbol_table.h:38](src/parser/scoped_symbol_table.h#L38)) is an `unordered_map` keyed by **name alone**, so the second definition overwrites the first. Verified: `f(1)` resolves to `FUNCTION_CALL(returns:FLOAT)` — the wrong overload. Needs signature-keyed symbols. |

---

## Explicitly Excluded (per spec)

Not required — no work planned.

| Feature | Status |
|:--------|:-------|
| Class and object | Grammar support exists anyway (`CLASS_TAG`, access specifiers, `this`, `new`/`delete`) — a bonus, not a requirement |
| Inheritance | ❌ excluded |
| Function call with variable arguments | ❌ excluded — note a varargs **prototype declarator** (`...`) isn't in the grammar; this only matters if a varargs function is ever explicitly declared, which the spec excludes |
| Lambda function | ❌ excluded |
| `public`/`private`/`protected` | Parses inside class bodies (bonus) |
| File manipulation | ❌ excluded |

---

## Out of scope right now (not defects)

Confirmed against `gcc` and the C standard so these can be defended directly
in a viva without conceding ground:

- **No type checking.** `int z = "string" + 1.5;`, redeclaring `int a;`
  twice in one scope, and calling an undeclared function all currently
  "succeed" (exit 0, clean label table). This is Stage 3's next slice, not
  a bug in what's built — labelling and type checking are different jobs.
- **No preprocessor.** `#` is a lexical error, so `#include`/`#define`
  cannot appear. Preprocessing is its own stage in this project's plan and
  is assumed absent from the input for now.
- **No format-specifier validation for `printf`/`scanf`.** Per C11
  §7.21.6.1p9, a bad conversion specifier is **undefined behavior at
  runtime**, not a translation-time error — the C standard doesn't require a
  compiler to check this. GCC's `-Wformat` is a non-standard extension
  driven by `__attribute__((format(printf,...)))` in `stdio.h`, and even
  then it only *warns* (confirmed: `gcc` exits 0 on `printf("%q\n", n)`).
  Checking it here would also need call-site type information — a
  semantic/type-checking concern, and it can't be done in the lexer since a
  string literal isn't necessarily a format string (`char *s = "100%q";` is
  legal C with no printf involved).
- **No C-style casts, no `sizeof`, no comma operator** (documented
  non-goals; casts/`sizeof` need typedef-name disambiguation, same
  underlying issue as the `typedef` defect above).

---

## Lexical analysis: malformed numeric literals (fixed)

**Defect:** malformed numerals were silently split into several
individually-valid tokens instead of being rejected. `123abc` became
`T_INT_CONST` + `T_IDENTIFIER`; `1.2.3.4` became three `T_FLOAT_CONST`s.
Both then surfaced as a *misleading syntax error* from the parser rather
than a lexical one.

**Why it must be fixed in the lexer, not the parser:** whitespace is
discarded during tokenization, so `123abc` and `123 abc` produce an
identical token stream. The adjacency information only exists inside the
lexer; once split, the parser cannot tell them apart.

**Fix — the C approach: over-match, then validate.** Real C lexers define a
deliberately over-broad *preprocessing number* (C11 §6.4.8) that greedily
absorbs digits, identifier characters, `.`, and exponent sign pairs, so any
numeric-looking run becomes **one** token; the token is validated afterward
and rejected if it isn't a legal constant. That is maximal munch (§6.4p4) —
match longest first, judge second.

Both `src/parser/parser_lexer.l` and `src/lexer/lexer.l` now do exactly
this. All the separate integer/float/bad-exponent rules were replaced by a
single pattern plus one validator, `classify_ppnumber()`:

```
PPNUM   ("."?{DIGIT})({DIGIT}|{LETTER}|"."|[eEpP][+-])*
```

`classify_ppnumber()` returns integer/float or logs a precise diagnostic —
reporting hex without digits, too many decimal points, an exponent with no
digits, a stray suffix, or an unsupported octal literal.

**Behaviour now, checked against `gcc` case by case:**

| Literal | This compiler | `gcc` |
|:--------|:--------------|:------|
| `0` `123` `0xFF` `1.0` `1.` `.5` `1e10` `2.5e-3` | accepted | accepted |
| `0x`, `0X` | invalid suffix | `invalid suffix "x" on integer constant` |
| `1.2.3.4`, `1.5.5`, `1..2` | too many decimal points | `too many decimal points in number` |
| `0xGG` | invalid suffix | `invalid suffix "xGG" on integer constant` |
| `1e`, `1e+`, `.5e`, `1.5e` | malformed scientific notation | `exponent has no digits` |
| `123abc`, `1_000`, `1e5e5` | invalid suffix | `invalid suffix ...` |
| `08` | Invalid Octal literal | `invalid digit "8" in octal constant` |
| `007`, `0b101`, `0x1p-3` | rejected | **accepted** — see below |

The last row is a deliberate language-scope difference, not a defect: this
language does not support octal literals, GNU binary literals, or C99 hex
floats, so it rejects what `gcc` accepts. Every other row agrees with `gcc`
on *which* forms are invalid, and all are now caught in the **lexical**
phase with a specific message.

**Regression status:** every previously-valid form still lexes; the existing
`Invalid Octal literal` and `malformed scientific notation` messages are
preserved verbatim so existing expected-output files still match. Member
access and float literals coexist correctly — `p.y`, `q.inner.x`,
`arr[0].x`, `1.`, `.5` and `1.5e-3` all tokenize as intended (verified: `.`
absorption does not swallow the `.` in member access, since a pp-number must
start with a digit or `.`+digit). Lexer suite 31/31; all 12 valid parser
outputs byte-identical to expected.

**Two related questions raised and resolved as non-issues** (viva record, no
code changed):

- **`&+` (e.g. `b &+ c`)** is legal C — it parses as `b & (+c)`, unary plus.
  `gcc` compiles it (exit 0), and this analyzer already accepts it. No C
  compiler keeps an "illegal operator pair" table: maximal munch tokenizes
  greedily and the *grammar* rejects what cannot combine. `a * / b` already
  fails to parse here exactly as in `gcc` (`expected expression before '/'`),
  and `a+++++b` is the standard's own example (§6.4p7) of input that
  tokenizes cleanly and fails only later ("lvalue required").
- **`printf`/`scanf` format specifiers** — out of scope, see above.

---

## Per-Feature Parser Test Suite

`tests/parser/valid/feature_NN_*.c` — one test per feature in the two tables
above, in specification order. Each file's header states four things: what the
**grammar** must accept, which **labels** the identifiers must carry, what is
**explicitly not a syntax-level concern**, and the **known defect** if the
feature has one. Tests whose feature carries a defect pin the *current, wrong*
output deliberately, so fixing the defect will fail the test and force the
expected file to be updated — that is the intent.

### Basic features

| # | Test | Labels verified | Explicitly NOT a syntax concern |
|:-:|:-----|:----------------|:--------------------------------|
| 01 | `arithmetic_logical_operators` | operands `INT_VARIABLE` | Operator semantics: no constant folding, no divide-by-zero, no overflow, no operand type compatibility. `a / 0` and `1.5 & 2` parse. |
| 02 | `if_else` | braced body opens `main.blockN` | Condition truthiness/type. `if (3.7)` parses. Branch reachability and exhaustiveness. |
| 03 | `for_loop` | counter `INT_VARIABLE` | Termination and trip count. A missing increment clause is well-formed. |
| 04 | `while_loop` | body decl → nested block scope | Whether the loop terminates. `while (1) {}` is flawless syntax. |
| 05 | `do_while_loop` | body decl → nested block scope | The defining "body runs at least once" behaviour — execution semantics, not shape. |
| 06 | `switch_case` | enum label → `ENUM_CONSTANT` | Duplicate case values, non-constant labels, non-integer operands, missing `break`. |
| 07 | `arrays` | `INT_ARRAY`, `CHAR_ARRAY`, `INT_ARRAY_PARAMETER` | **Bounds.** `numbers[999]` on a 5-element array parses; the extent is not even stored. Initializer length vs declared size. |
| 08 | `pointers` | `INT_POINTER`, `CHAR_POINTER`, `INT_POINTER_PARAMETER` | Null-ness, dangling pointers, dereference validity, aliasing, pointer/integer mismatch. |
| 09 | `structure` | `STRUCT_TAG`, `STRUCT_VARIABLE`, `STRUCT_POINTER`, `STRUCT_PARAMETER` | Member access after `.`/`->` is **deliberately unlabelled** (one flat scope stack, no member namespace). Member existence, offsets, `.` vs `->` correctness. |
| 10 | `printf_scanf` | `FUNCTION_CALL(returns:UNKNOWN)` — correct, they are genuinely undeclared | **Format strings entirely.** C11 §7.21.6.1p9 makes a bad specifier runtime UB, not a translation error; gcc's `-Wformat` is a non-standard extension that only warns. Needs call-site types, and cannot live in the lexer since a literal need not be a format string. |
| 11 | `function_call_args` | same name → `FUNCTION_PROTOTYPE` / `_DEFINITION` / `_CALL`, return type carried | **Argument count and types.** `add(1)` and `add(1,2,3)` would parse. Missing return value. |
| 12 | `goto_break_continue` | `LABEL` at both definition and reference, forward and backward | Whether a label is defined, unused, or duplicated — `goto missing;` still labels `LABEL`. Jumping into a block or over an initialization. Whether `break` sits inside a loop. |
| 13 | `static` | ⚠ `INT_VARIABLE` — **defect**, `static` is parsed then discarded | What `static` *means*: internal linkage, preserved storage duration. Both are semantic/codegen properties. |

### Advanced features

| # | Test | Labels verified | Explicitly NOT a syntax concern |
|:-:|:-----|:----------------|:--------------------------------|
| 14 | `recursion` | self-call → `FUNCTION_CALL(returns:INT)`; mutual recursion via prototypes | Termination and stack depth. `spin(n)` recurses forever and is valid syntax. |
| 15 | `dynamic_memory` | `INT_POINTER`, `CHAR_POINTER`; `malloc`/`free` → `returns:UNKNOWN` | Leaks, double free, use-after-free, `delete` vs `delete[]` mismatch. Allocation size is not stored. |
| 16 | `function_pointer` | ⚠ `FUNCTION_PROTOTYPE(returns:INT)` — **defect**, "pointer to" is lost entirely | Whether the assigned function's signature matches the pointer's. |
| 17 | `command_line_input` | `argc` → `INT_PARAMETER` ✓; ⚠ `argv` → `CHAR_ARRAY_PARAMETER` — **defect**, pointer dropped | argc/argv agreement, NULL termination, `argv[i]` range. |
| 18 | `typedef` | `TYPEDEF_NAME` | Type identity/aliasing. **The alias cannot be used as a type** — pinned by `invalid/syntax_invalid_typedef_use.c`. |
| 19 | `reference` | ⚠ `INT_VARIABLE` / `INT_PARAMETER` — **defect**, the `&` is discarded | Must-be-initialized, cannot-be-reseated, cannot-be-null. `int &loose;` would parse. |
| 20 | `enum_union` | `ENUM_TAG`, `UNION_TAG`, `ENUM_CONSTANT`, `ENUM_VARIABLE`, `UNION_VARIABLE`, `UNION_POINTER` | Enum: assigned value need not be an enumerator (`c = 999;` parses). Union: that only one member is active at a time. Member offsets and union size. |
| 21 | `until_loop` | body decl → nested block scope | The inverted-condition semantics. Nothing in the output distinguishes `until` from `while`. |
| 22 | `multi_level_pointers` | `INT_POINTER` ✓, then ⚠ **saturates** — depth 2, 3 and 4 all render `INT_POINTER_POINTER` | Whether a dereference chain matches the declared depth. |
| 23 | `multi_dimensional_arrays` | ⚠ all ranks → `INT_ARRAY` — **rank and extents discarded** | Bounds on any dimension; subscript count vs declared rank. Extents must be retained before IR can do address arithmetic. |
| 24 | `function_overloading` | ⚠ all calls → `FUNCTION_CALL(returns:INT)` — **defect**, symbol map keyed by name alone so only the last definition survives | Overload **resolution** is inherently type checking. Ambiguity detection; overloads differing only by return type. |

### What "not a syntax concern" means here

Three distinct reasons appear above, and they are worth separating in a viva:

1. **Belongs to a later stage.** Argument arity/types, operand compatibility,
   overload resolution, enum range. These are *type checking* — real work,
   simply not this stage's.
2. **Not decidable, or not a compiler's job.** Loop and recursion
   termination, memory leaks, dereference validity. No C compiler diagnoses
   these from the grammar either.
3. **Not required by the C standard at all.** `printf` format specifiers are
   runtime undefined behaviour (C11 §7.21.6.1p9); gcc's check is an optional,
   warning-only extension.

Separately, ⚠ marks a **labelling defect** — something this stage *should*
get right and currently does not. Those are listed in the two feature tables
at the top and are the next work item, not out-of-scope items.

---

## Test Coverage

| Suite | Tests | Result |
|:------|:-----:|:-------|
| Parser — per-feature (`feature_NN_*`) | 24 | ✅ 24/24 |
| Parser — other valid | 14 | ✅ 14/14 |
| Parser — invalid | 17 | ✅ 17/17 |
| **Parser total** | **55** | **✅ 55/55** |
| Lexer — valid | 21 | ✅ 21/21 |
| Lexer — invalid | 14 | ✅ 14/14 |
| **Lexer total** | **35** | **✅ 35/35** |

Both suites pass from a clean build, with no compiler or Bison warnings.

### Tests added for numeric-literal handling

| Test | Covers |
|:-----|:-------|
| `lexer/valid/valid_numeric_boundaries.c` | Every accepted numeric form — decimal, hex (both cases), `1.`, `.5`, `1.e3`, `.5e2`, and all exponent spellings. Guards against the pp-number rule over-rejecting. |
| `lexer/valid/valid_dot_number_adjacency.c` | Maximal munch around `.`: member access (`p.x`), `.5`, `arr[0].y = 1.`, and `..2131` → `T_DOT` `T_FLOAT_CONST`. |
| `lexer/valid/valid_float_trailing_dot.c` | `1.`, `.5`, `1.e3` are legal C floats. **Relocated** from `invalid/invalid_malformed_float.c`, which produced no errors at all — the premise was wrong, not the lexer. |
| `lexer/invalid/invalid_numeric_suffix.c` | `123abc`, `0x`, `0xGG`, `1_000`, `1e5e5`, `0b101`, `0x1p-3` — 7 distinct suffix failures. |
| `lexer/invalid/invalid_decimal_points.c` | `1.2.3.4`, `1.5.5`, `1..2`, and `...1231.131` (leading dots split off, tail is one bad number). |
| `parser/invalid/syntax_invalid_bad_numeric_literal.c` | A malformed literal aborts in the **lexical** phase, before parsing. |
| `parser/invalid/syntax_invalid_stray_dots.c` | `..2131` is lexically *valid* (`T_DOT` + `T_FLOAT_CONST`) and is rejected one phase later, by the **parser**. Deliberate contrast with the row above. |

### Test harness strengthened

`scripts/run_lexer_tests.sh` previously compared only the token stream. Since
a rejected token is simply *absent* from that stream, every lexical error
looked identical — a wrong or wrongly-worded diagnostic still passed. The
runner now also compares `out/error_log_<stem>.txt` against an expected file
under `tests/lexer/expected/errors/` when one exists (optional, so tests
without one behave as before). Expected error logs are now recorded for all
14 invalid lexer tests.

Verified by fault injection: disabling the decimal-point check makes
`invalid_decimal_points` fail, and changing the octal message makes
`invalid_octal_literal` fail. Before this change, **neither** was detected.

### Feature showcase

`parser/valid/syntax_valid_full_spec_showcase.c` (992 tokens) exercises every
feature in the specification in one program — all operators, every loop form
including `until`, `switch`, arrays, multi-dimensional arrays, pointers to
three levels, references, `struct`/`union`/`enum`/`typedef`, `static`,
`printf`/`scanf`, `goto`/`break`/`continue`, recursion and mutual recursion,
overloading, function pointers, `new`/`delete`, and `argc`/`argv`.

Its output doubles as a live demonstration of the labelling defects listed
above: `op` is labelled `FUNCTION_PROTOTYPE` rather than a function pointer,
`ref` as a plain `INT_VARIABLE`, `argv` as `CHAR_ARRAY_PARAMETER`, the
`add(1, 2)` call resolves to `returns:FLOAT`, and `ppp` is indistinguishable
from `pp`.

```bash
make -f Makefile.parser        # build syntax_analyzer
make -f Makefile.lexer         # build lexer_app
bash scripts/run_parser_tests.sh
bash scripts/run_lexer_tests.sh
```

---

## Repository hygiene (fixed)

**`.gitignore` was hiding the entire parser source tree.** Line 8 read:

```
src/**/parser
```

Intended to ignore a compiled binary named `parser`, it also matched the
**directory** `src/parser/`, so `parser.y`, `parser_lexer.l` and their
headers were invisible to git — a fresh clone would not have built the
parser, and no parser work was committed. What git tracked instead was an
older copy at the previous flat paths (`src/parser.y`, …), staged but stale.

**Fixed:**

- Removed the `src/**/parser` rule. No binary named `parser` is ever built —
  the Makefiles emit `syntax_analyzer` and `lexer_app` to the project root,
  both already ignored by name — so the rule was vestigial as well as
  harmful. A comment now records why it must not come back.
- Generated Flex/Bison files are matched by **filename at any depth**
  (`lex.yy.c`, `parser.tab.c`, …) rather than by full path, so they stay
  ignored regardless of directory layout. This also covers the stale copies
  still sitting in `src/`.
- Added a `NUL` rule. The Makefiles use Windows-style `2>NUL` redirects; run
  under a POSIX shell these create a file literally named `NUL` on every
  build, which has been committed by accident before (commit 6c001c5,
  "Delete src/NUL"). The root cause is in the Makefile recipes and is worth
  fixing separately.
- Removed the five stale flat-path duplicates (`src/common.h`,
  `src/parser.y`, `src/parser_lexer.l`, `src/scoped_symbol_table.h`,
  `src/semantic_types.h`) and unstaged them, leaving `src/parser/` as the
  single source of truth. Three were byte-identical to their `src/parser/`
  counterparts; the other two were older. The one thing the stale
  `src/parser.y` had that the live copy lacked — the modern
  `%define parse.error verbose` directive — was carried across first (see
  below).

`git add src/parser/` now stages exactly the five source files and nothing
else. **Committing them is still outstanding and is the first thing to do.**

---

## Bison directive modernized — last failing test now passes

`src/parser/parser.y` used the deprecated `%error-verbose`, which made the
installed Bison emit `"unexpected $end"` where the committed expected file
said `"unexpected end of file"`. That mismatch was the single long-standing
parser-test failure, and had been worked around locally by editing the
expected file rather than the grammar.

Replacing it with the modern `%define parse.error verbose` restores the
`"unexpected end of file"` wording, matching the committed expected file. The
local edit to the expected file was reverted, and the Bison deprecation
warning is gone from the build.

**Parser suite is now 26/26.**

---

## Suggested Order of Work

1. **Commit `src/parser/`** — `.gitignore` is fixed and the sources are now
   visible to git, but they are still untracked. Nothing else matters until
   the parser source is actually in version control.
2. **Fix the remaining labelling defects** found above: `static`, references,
   function pointers, `char *argv[]`, multi-level pointer display, overload
   keying (signature-based, not name-only). None require an AST.
3. **Resolve `typedef` name usage** (lexer feedback or a parser-side
   type-name table) — needed before casts/`sizeof` can be added too.
4. **Fix the Makefiles' `2>NUL` redirects** so builds stop creating a stray
   `NUL` file under POSIX shells (now ignored, but the cause remains).
5. When ready to leave the labelling stage: **add a real semantic pass**
   (type checking, redeclaration detection, undeclared-use errors, call
   arity/type checking, struct member resolution with offsets).
6. **Build an AST** — prerequisite for 3AC; the single-pass classify-as-you-
   parse design that works for labelling won't extend to control-flow IR.
7. **Add a minimal preprocessor** (`#include` skipping, `#define`) once
   preprocessing becomes its own stage.
8. **Emit 3AC**, then **x86**.
