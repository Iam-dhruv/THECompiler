# IR Generator Internals — a complete mental model of `src/ir/`

This document explains how `ir_generator` turns a source program into
three-address code (3AC): what every piece of state means, why each design
decision was made, and how the tricky cases are handled. Read it top to
bottom once; afterwards use the section headings as a map.

Everything here describes the code on branch `ir` (`src/ir/`). The other two
stages (`src/lexer/`, `src/parser/`) are independent programs and are only
mentioned where they differ.

---

## Contents

1. [The 30-second version](#1-the-30-second-version)
2. [Files and how they depend on each other](#2-files-and-how-they-depend-on-each-other)
3. [The lexer](#3-the-lexer)
4. [Types: `TypeInfo`](#4-types-typeinfo)
5. [Symbol tables](#5-symbol-tables)
6. [The IR model: quads, data, printing](#6-the-ir-model-quads-data-printing)
7. [`ExprAttr` — the central abstraction](#7-exprattr--the-central-abstraction)
8. [Translating expressions](#8-translating-expressions)
9. [Translating statements: backpatching](#9-translating-statements-backpatching)
10. [Declarations, functions, structs, enums, typedefs](#10-declarations-functions-structs-enums-typedefs)
11. [Initializers](#11-initializers)
12. [Errors: detection, propagation, reporting](#12-errors-detection-propagation-reporting)
13. [Annotated walkthrough of a real program](#13-annotated-walkthrough-of-a-real-program)
14. [Edge-case catalog](#14-edge-case-catalog)
15. [Known limitations and leniencies](#15-known-limitations-and-leniencies)
16. [Testing, and how to extend the generator](#16-testing-and-how-to-extend-the-generator)
17. [Glossary](#17-glossary)

---

## 1. The 30-second version

- **One pass, no syntax tree.** Bison parses the program bottom-up. Every
  grammar action does three things immediately: look names up in a scoped
  symbol table, **type-check** its operands, then **emit** quads into a
  global vector `g_code`. Nothing is ever revisited except jump targets.
- **Expressions carry an `ExprAttr`.** It records *where* a value lives (a
  variable, a byte offset in a variable, behind a pointer, or already in a
  temp) instead of loading it eagerly. Loads happen only where a value is
  really needed, so assignment targets are never read.
- **Conditions are jumps, not values.** `a < b` produces two unfinished
  jumps (a *truelist* and a *falselist*). Statements fill in their targets
  later — this is **backpatching**, and it is what makes `&&`/`||`
  short-circuit and lets loops work without a tree.
- **Type checking guards emission.** Every helper checks types first and
  returns an *error expression* if they are wrong; error expressions
  silently absorb further checks so one mistake yields one message. If any
  semantic error was recorded, no `.ir` file is written.
- **Output:** `.types` (struct layouts), `.data` (globals, statics, string
  literals), `.text` (functions with numbered quads).

---

## 2. Files and how they depend on each other

```
ir_lexer.l ─────────────┐
                        ▼
                  parser.tab.h  (generated from ir.y; its "%code requires"
                        │        block pulls in type_check.h)
                        ▼
                  type_check.h ──► ir_gen.h ──► semantic_types.h
                        │                            ▲
                        └──► scoped_symbol_table.h ──┘
ir.y (grammar + declaration/statement logic + main)
```

| File | Owns | Key contents |
|:-----|:-----|:-------------|
| `semantic_types.h` | **What a type is** | `TypeInfo`, struct/union layouts (`g_layouts`), `sizeof_type`, `alignof_type`, `decay`, `pointee`, `pointer_to`, `element_type`, `same_type`, `type_to_string`, name mangling |
| `scoped_symbol_table.h` | **What a name means** | `SymbolInfo`, `ScopedSymbolTable`, the overload sets `g_functions` |
| `ir_gen.h` | **What the output is** | `Quad`, `g_code`, `emit*`, `makelist`/`merge`/`backpatch`, temporaries, `.data` entries, the string pool, `FuncRecord`, `write_ir` |
| `type_check.h` | **Expressions** | `ExprAttr`, `sem_error`, value/address/store helpers, jump form, conversions, every operator, calls and overload resolution, `new`/`delete`/`return` |
| `ir.y` | **Grammar, declarations, statements** | declarators and `build_type`, `declare_object`, initializers, struct/enum definitions, function begin/end, statement backpatching, ternary, switch, labels, `main()` |
| `ir_lexer.l` | **Tokens** | numeric-literal validation, char/string literals, typedef-name feedback |
| `common.h` | `TokenRecord {lexeme, line}` | |
| `string_pool.h` | interned lexeme strings (stable `const char*`) | |

**Why every function in the headers is `inline`.** The headers are compiled
into two translation units: `parser.tab.c` and `lex.yy.ir.c` (the lexer
includes `parser.tab.h`, which includes `type_check.h`). A non-`inline`
function or global defined in a header would be defined twice and fail to
link. C++17 `inline` functions *and* `inline` variables (e.g.
`inline std::vector<Quad> g_code;`) give exactly one definition shared by
both units. Globals defined in `ir.y` itself (`g_symtab`, `g_tokens`, …) are
ordinary definitions and the lexer refers to them with `extern`.

**Build.** `Makefile.ir`: `bison -d ir.y` → `parser.tab.c/.h`;
`flex ir_lexer.l` → `lex.yy.ir.c`; `g++ -std=c++17` links both into
`./ir_generator`. The grammar has **0 conflicts**.

---

## 3. The lexer

`ir_lexer.l` is a copy of the parser's lexer with three changes.

### 3.1 Every token remembers its line

```cpp
#define RET_LEXEME(tokcode, lex) \
    do { g_tokens.push_back({g_string_pool.intern(lex), yylineno}); \
         yylval.token_index = (int)g_tokens.size() - 1; \
         g_prev_token = (tokcode); \
         return tokcode; } while (0)
```

Every token (not just identifiers) is appended to `g_tokens` and its index is
the semantic value. Grammar actions write `TOK_LINE($<token_index>2)` to get
the line of, say, the operator token. That is why error messages point at the
right line even though Bison reduces rules lazily (often after reading the
next token, which may be on a later line).

### 3.2 Typedef-name feedback (the classic "lexer hack")

C's grammar cannot tell `Integer x;` (a declaration) from `a * b;` style
ambiguities unless the lexer knows which identifiers are type names. The IR
lexer asks the symbol table:

```cpp
SymbolInfo* s = g_symtab.lookup(yytext);
if (s && s->kind == SK_TYPEDEF) RET(T_TYPE_NAME);
```

and the grammar has `type_specifier : T_TYPE_NAME`.

Two subtleties:

- **Timing.** `typedef int Integer; Integer x;` works because Bison reduces
  `init_declarator` (which inserts the typedef) when it sees the `;`
  lookahead — before the lexer is asked for the next token `Integer`.
- **Tag positions.** After `struct`, `union`, `enum`, `class`, `.`, `->` and
  `goto`, an identifier can only be a tag, member or label, so it is never
  turned into `T_TYPE_NAME` (`g_prev_token` tracks the previous token). This
  allows `typedef struct Node Node;` style code and member names that
  coincide with typedef names.

A variable that *shadows* a typedef (`{ int Integer; … }`) cannot be declared
— the declarator name itself would be lexed as a type name. This is the
standard limitation of the lexer hack.

### 3.3 Char literals fixed

The parser lexer's patterns were double-escaped (`[^\\'\\n]` excludes the
letter `n`), so `'n'`, `'\n'`, `'\0'` failed. The IR lexer uses
`'([^\\'\n]|\\[ntr\\'\"abfv0])'`. Multi-character (`'ab'`) and unterminated
literals are still lexical errors.

### 3.4 Lexical errors are fatal

On a lexical error the lexer logs a message and returns `0` (end of input).
`main` then prints only the lexical errors and exits `1`.

---

## 4. Types: `TypeInfo`

### 4.1 Reading a `TypeInfo`

```cpp
struct TypeInfo {
    BaseKind base_kind;      // INT CHAR FLOAT DOUBLE VOID STRUCT UNION ENUM CLASS ERROR
    int  pointer_depth;      // pointers applied to the base
    int  outer_pointer;      // pointers to the whole array
    bool is_typedef, is_const, is_static;   // declaration-only flags
    bool is_reference;       // T&
    bool is_func_ptr;        // with func_info: pointer to that function
    optional<FunctionTypeInfo>  func_info;      // return type + parameter types
    optional<ArrayTypeInfo>     array_info;     // dims, outermost first; -1 = "[]"
    optional<CompositeTypeInfo> composite_info; // struct/union/enum/class tag
};
```

Read it **inside-out**:

```
base_kind  →  pointer_depth × "*"  →  array dims  →  outer_pointer × "(*)"
```

| C declaration | base | pointer_depth | dims | outer_pointer | printed |
|:--|:--|:-:|:--|:-:|:--|
| `int x` | int | 0 | – | 0 | `int` |
| `char **pp` | char | 2 | – | 0 | `char**` |
| `int *a[3]` (array of 3 pointers) | int | 1 | [3] | 0 | `int*[3]` |
| `int m[2][3]` | int | 0 | [2,3] | 0 | `int[2][3]` |
| `int (*row)[3]` (pointer to array) | int | 0 | [3] | 1 | `int(*)[3]` |
| `int &r` | int | 0 | – | 0 (`is_reference`) | `int&` |
| `int (*op)(int,int)` | (int) | – | – | – (`func_info`, `is_func_ptr`) | `int(*)(int,int)` |

**Why `outer_pointer` exists.** `int m[][3]` as a parameter, and a 2-D array
used as a value, both mean "pointer to an array of 3 ints". With only
`pointer_depth` (which sits *inside* the array) that type cannot be written,
so pointer-to-array is a separate counter.

**Functions.** A function and a function pointer both store their signature
in `func_info`. `is_func_ptr` distinguishes them. For functions,
`base_kind` mirrors the return type's base only for convenience; the real
return type is `return_type()`.

### 4.2 Predicates (all in `TypeInfo`)

| Predicate | True when |
|:--|:--|
| `is_array()` | has `array_info` **and** `outer_pointer == 0` |
| `is_plain()` | no `array_info` and no `func_info` |
| `is_pointer()` | function pointer, or `outer_pointer > 0`, or plain with `pointer_depth > 0` |
| `is_integral()` | plain, depth 0, base char/int/enum |
| `is_floating()` | plain, depth 0, base float/double |
| `is_arith()` | integral or floating |
| `is_scalar()` | arith or pointer (what `if`, `!`, `&&` accept) |
| `is_composite()` | plain, depth 0, base struct/union/class |
| `is_void()` | plain, depth 0, base void |

`is_plain()` deliberately excludes pointer-to-array, otherwise
`int(*)[3]` (depth 0) would look integral.

### 4.3 Derived types

| Function | Meaning | Note |
|:--|:--|:--|
| `element_type(t)` | type of `a[i]` for array `a` | removes the first dim |
| `pointee(t)` | type of `*p` | decrements `outer_pointer` first, else `pointer_depth` |
| `pointer_to(t)` | type of `&x` | increments `outer_pointer` if there is array info, else `pointer_depth` |
| `decay(t)` | value of an array / function | `int[3]→int*`, `int[2][3]→int(*)[3]`, function → function pointer; clears `is_reference` |

### 4.4 Size and alignment

`sizeof_type`: char 1; int, float, enum 4; double 8; any pointer,
reference, function pointer or pointer-to-array 8; struct/union from its
layout (0 if incomplete); arrays multiply by every dim (an unknown `-1` dim
gives 0). Alignment is the same for scalars, the element's for arrays, the
layout's for composites.

**Size 0 means "incomplete".** Many checks use it: declaring a variable of an
incomplete struct, pointer arithmetic on `void*` or `struct Z*`, `new` of an
incomplete type.

### 4.5 Equality

`same_type(a, b)` compares base, depths, dims, tag, and function signatures
(including whether each parameter is a reference). It **ignores** the
declaration flags (`static`, `typedef`, `const`) and the *outer*
`is_reference` (a reference parameter compares equal to its referent type
where that matters). It returns `true` if either side is an error type, so
an error never causes a second "type mismatch" message.

### 4.6 Name mangling

Overloads need distinct names in the IR. `mangle_function(name, fn)` gives
`name@<codes>` (`main` is never mangled):

| Code | Meaning | Example |
|:--|:--|:--|
| `i c f d v` | int char float double void | `add@ii` |
| `P` | one pointer (or decayed array) level | `show@iPPc` (int, char**) |
| `R` | reference prefix | `bump@Ri` |
| `S<len><tag>`, `U…`, `C…`, `e…` | struct, union, class, enum | `sum@S5Point` |
| `PA<n>_` | pointer to array of n | `corner@PA3_ii` |
| `PF<ret><params>E` | function pointer | `apply@PFiiiEi` |
| `v` alone | no parameters | `pick@v` |

The return type is **not** part of the mangled name. That is exactly why two
declarations differing only in return type collide and are reported.

---

## 5. Symbol tables

### 5.1 `ScopedSymbolTable` — names to meanings

A stack of scopes, each an `unordered_map<string, SymbolInfo>`.
`lookup` walks innermost → outermost; `lookup_current` checks only the
innermost scope (used for "redeclaration in the same scope");
`lookup_global` checks only the outermost.

```cpp
struct SymbolInfo {
    SymKind kind;            // SK_VAR, SK_FUNC, SK_ENUM_CONST, SK_TYPEDEF
    TypeInfo type_info;
    std::string ir_name;     // name used in the IR (may differ from source)
    long enum_value;         // SK_ENUM_CONST
    bool static_storage;     // global or static → lives in .data
    ...
};
```

**Scopes that exist:** global; one per function (named after the function —
parameters and the body's top level share it, so `int f(int a){ int a; }`
is a redeclaration, as in C); one per `{ }` block; one per `for` statement
(so `for (int i…)` is scoped to the loop); one per `switch` body. Struct,
union and enum bodies do **not** push a scope: members go into the layout,
enumerators into the enclosing scope.

**Pointer stability.** Code keeps `SymbolInfo*` across insertions (e.g.
between the two halves of `int x = …`). `unordered_map` never moves its
nodes on insert, so those pointers stay valid. A pointer is never kept past
the scope's `pop_scope`.

### 5.2 `g_functions` — overload sets

A function name has **one** `SK_FUNC` entry in the global scope (so normal
lookup and shadowing work) and a list of overloads in
`g_functions[name]`, each a `FuncSym {type, mangled, defined, line}`.
Prototypes create entries with `defined = false`; a definition sets it.

### 5.3 IR names

Source names are not unique within a function (`int x; { int x; }`) and could
collide with globals or temporaries, so each object gets an `ir_name`:

- **Locals and parameters:** `unique_local_name` — the source name, unless
  it is already used in this function, is a `.data` name, or looks like a
  temporary (`t` + digits); then `.1`, `.2`, … is appended (`x.1`).
- **Globals:** `unique_global_name` — same rule against `.data` names and
  temp-like names.
- **Static locals:** `unique_static_name` — `<mangled function>.<name>`,
  e.g. `bump@i.hidden`, `main.cache`.

Because user names that look like `t7` are always renamed, any operand
of the form `t<digits>` in the output is guaranteed to be a temporary
(`looks_like_temp` relies on this).

---

## 6. The IR model: quads, data, printing

### 6.1 Quads

```cpp
struct Quad { std::string op, a1, a2, res; int target = -1; };
inline std::vector<Quad> g_code;     // the whole program, in order
```

`nextquad()` is the index the next `emit` will use. Quad indices are global
across the file, which is why the second function's instructions continue
numbering where the first stopped. Jump targets are quad indices.

| `op` | Printed as | Meaning |
|:--|:--|:--|
| `=` | `x = a` | copy |
| `+ - * / % << >> & \| ^` | `x = a op b` | binary operator |
| `neg`, `~` | `x = -a`, `x = ~a` | unary |
| `cast` | `x = (float) a` | conversion (`a2` = target type) |
| `addr` | `x = &a` | address of a variable |
| `deref` | `x = *a` | load through pointer |
| `*=` | `*x = a` | store through pointer |
| `=[]` | `x = a[b]` | load the object **b bytes** into variable a |
| `[]=` | `x[a] = b` | store into the object **a bytes** into variable x |
| `goto` | `goto T` | |
| `if` | `if a goto T` / `if a rel b goto T` | relop kept in `res` |
| `param` | `param a` | |
| `call`, `icall` | `[x =] call f, n` | direct / through a pointer |
| `return` | `return [a]` | |
| `new`, `delete` | `x = new n`, `delete a` | |

Address-of has its own op name (`addr`) because `&` is already bitwise AND —
sharing one name once printed `b & 1` as `&b`.

**Indexed quads are byte offsets into a *variable's own storage*.** `a[8]`
means "the object 8 bytes into variable `a`" — never "8 bytes past the
address stored in `a`". Pointers therefore never use indexed quads; `p[i]`
becomes `t = p + i*size` then `*t`. This keeps one meaning per quad form.

**Address constants.** Two operand forms denote addresses without any
instruction: `.strN` (a string literal in `.data`) and `&name@sig` (a
function). Inside global/static initializers `&global` is also an address
constant.

### 6.2 Backpatch lists

```cpp
using List = std::vector<int>;            // quad indices of unfinished jumps
makelist(q)  merge(a, b)  backpatch(list, target)
```

`emit_goto()` and `emit_if(...)` create jumps with `target = -1`.
`backpatch` fills them in.

### 6.3 Temporaries

`new_temp()` returns `t1, t2, …`. The counter is reset in `begin_function`,
so temporaries are numbered per function.

### 6.4 `.data` and the string pool

`add_data(name, type, size, init, comment)` appends an entry;
`g_data_names` tracks names for uniqueness checks. Globals start with init
`"0"` and are updated after their initializer is parsed.

`intern_string(raw)` returns `.strN`, creating the entry on first use;
identical literals share one entry. **Strings are interned lazily** — only
when an expression actually needs the string's address (`rval`). A literal
used to initialize a char array (`char s[] = "hi"`) is copied byte by byte
and never appears in `.data`.

### 6.5 `FuncRecord` and the printer

Each function records its mangled name, parameter and local lists
(`name:type`) and its quad range `[start, end)`. `write_ir`:

1. **Validates** every `goto`/`if`: its target must be in `0..nextquad()`.
   An unpatched jump means a generator bug; `main` deletes the half-written
   file and exits with code **2**.
2. Prints `.types` (only if a layout exists), `.data`, `.text`.

---

## 7. `ExprAttr` — the central abstraction

Every expression non-terminal produces an `ExprAttr*`. Understanding its
states is understanding the generator.

```cpp
struct ExprAttr {
    TypeInfo type;
    LvalKind lv;              // LV_NONE, LV_NAME, LV_INDEX, LV_DEREF
    std::string addr, index;
    bool is_cond; List truelist, falselist;     // jump form
    bool has_const; long cval;                  // integer constant expression
    bool is_float_lit;                          // floating literal (text in addr)
    bool is_string; std::string str_value;      // string literal
    bool is_funcset; std::string func_name;     // function name, overload not chosen
    bool static_storage;                        // names a global/static object
    int line;
};
```

### 7.1 Where the value is: `lv`

| `lv` | Meaning | `addr` | `index` | Read (`rval`) | Write (`store`) |
|:--|:--|:--|:--|:--|:--|
| `LV_NONE` | already a value | temp, constant, or copy of a name | – | `addr` | not allowed |
| `LV_NAME` | the variable itself | variable's IR name | – | `addr` (no code) | `x = v` |
| `LV_INDEX` | object at a byte offset inside a variable | variable | offset (literal or temp) | `t = x[i]` | `x[i] = v` |
| `LV_DEREF` | object a pointer points to | pointer (name/temp) | – | `t = *p` | `*p = v` |

Arrays and functions never load: `rval` of an array yields its **address**
(`t = &a`, or `&a` + offset), of a function-through-pointer yields the
pointer. That is decay.

### 7.2 Why loads are deferred

If `a[i]` produced `t = a[t1]` immediately, `a[i] = 5` would load a value it
then throws away, and `&a[i]` would have nothing to take the address of. By
keeping the *location* until a consumer decides, each consumer emits exactly
what it needs:

- `store` writes to the location,
- `rval` loads from it,
- `address_of_object` computes its address,
- `member_expr` / `index_expr` refine it (add an offset).

### 7.3 The core helpers (`type_check.h`)

| Helper | What it does |
|:--|:--|
| `rval(e)` | returns an operand string holding e's value, emitting a load if needed; converts jump form first; interns strings; resolves a single-overload function name to `&f@sig` |
| `make_rvalue(e)` | `rval` **in place**: afterwards `e` is `LV_NONE` and arrays/functions have decayed types. Idempotent |
| `address_of_object(e)` | address of an lvalue: `t = &x`; `t1 = &x; t2 = t1 + off`; or the pointer itself for `LV_DEREF` |
| `store(lhs, v)` | emits the right store for the lvalue kind |
| `to_cond(e)` | value → jump form: `if v goto _` / `goto _` |
| `to_value(e)` | jump form → value: `t = 1` / `goto +2` / `t = 0` |

### 7.4 Jump form

When `is_cond` is set, the expression has *no value yet*; it is a pair of
lists of jumps that must be pointed at "where to go if true" and "where to
go if false". Produced by relational operators, `&&`, `||`, `!` and by
`to_cond`. Consumers:

- **statements** (`if`, loops) backpatch the lists to code positions;
- **value contexts** call `to_value`:

```
  backpatch(true)  →  k:   t = 1
                      k+1: goto k+3
  backpatch(false) →  k+2: t = 0
```

**Constant conditions** produce only the jump that can be taken:
`to_cond` on constant `1` gives just `goto _` in the truelist and an empty
falselist (`while (1)` → one unconditional jump).

### 7.5 Constants

`has_const`/`cval` mark integer constant expressions (int and char literals,
enumerators, and anything folded from them). They make array sizes, `case`
labels, enumerator values and global initializers checkable, and enable
folding. Char literals keep their source text in `addr` (`'a'`) but carry the
numeric value in `cval`.

### 7.6 `is_funcset`

A function name in an expression is *not* resolved immediately, because the
right overload depends on context:

- **called** → resolved by its arguments (`resolve_overload`);
- **assigned/passed to a function pointer** → resolved by the pointer's
  signature (`assign_value`, `arg_rank`);
- **used plainly** (`&f`, `f` as a value) → only legal with exactly one
  overload (`resolve_funcset_single`).

---

## 8. Translating expressions

### 8.1 The evaluation-order rule for binary operators

Every binary rule has a mid-rule action:

```yacc
additive_expr : additive_expr T_PLUS { make_rvalue($1); } multiplicative_expr { … }
```

The left operand is turned into a value **after the operator is seen but
before the right operand is parsed**. Two reasons:

1. **Correctness for jump form.** `(x < y) + (z < w)`: the left operand is
   two pending jumps. If it were converted to a value only at the end, its
   `t = 1/0` code would be placed *after* the right operand's code, and the
   left operand's jumps would skip the right operand entirely.
2. **Readable order.** Loads of the left operand appear before the right
   operand's code, matching source order.

The same idea applies to function arguments (`to_value` as each argument is
reduced) and initializer elements.

### 8.2 Arithmetic: `arith_binary`

1. Error operand → error result (no message).
2. `make_rvalue` both.
3. `+`/`-` with a pointer → `pointer_arith`.
4. Type rule: `% << >> & | ^` need integral operands; others need
   arithmetic. Otherwise: *invalid operands to binary 'op'*.
5. **Folding:** both integer constants and `fold_int` succeeds → a constant
   expression, no code. Folding uses 32-bit wrap-around and refuses
   division/modulo by zero and out-of-range shifts (those are emitted).
6. Result type: `arith_result` — double if either is double, else float if
   either is float, else int (char/enum promote to int). Shifts are always int.
7. `cast_value` converts each operand to the result type, then
   `t = a op b`.

### 8.3 Conversions: `needs_cast` and `cast_value`

A cast quad is emitted only when crossing **integer ↔ floating** or
**float ↔ double**. char/int/enum are one integer class: no cast.
`cast_value` folds literal conversions instead of emitting them:

| Source | To floating | To integer |
|:--|:--|:--|
| integer constant `2` | `2.0` | (no cast needed) |
| float literal `7.9` | unchanged | `7` (truncated) |
| anything else | `t = (float) x` | `t = (int) x` |

Floating literals have type **float** (the language has no suffixes), so
`add(1.5, 2.5)` matches `add(float, float)` exactly.

### 8.4 Assignment compatibility: `assign_value`

Used for `=`, initialization, argument passing and `return` — one rule set
for all four:

| Target | Accepts |
|:--|:--|
| arithmetic (incl. enum, char) | any arithmetic (with cast if needed) |
| function pointer | function pointer of the same signature; a function name with a matching overload (→ `&f@sig`) |
| object pointer | same pointer type (after decay), `void*` either direction, the constant `0` |
| struct/union | same struct/union |

Anything else: *incompatible types in <what> ('from' to 'to')*. On success
it returns `cast_value(e, rval(e), to)`.

### 8.5 Pointer arithmetic: `pointer_arith`

| Expression | Code | Result type |
|:--|:--|:--|
| `p + n`, `n + p`, `p - n` | `t = p + n*size` (offset folded if `n` constant) | p's type |
| `p - q` (same type) | `t1 = p - q; t2 = t1 / size` (no divide for size 1) | int |
| anything else, or pointee size 0 (`void*`, incomplete) | error | |

### 8.6 Relational and logical operators

- **`relational(rel, a, b)`**: arithmetic operands get a common type (with
  casts); pointers must be the same type or `void*`; a pointer may be
  compared with constant `0`. Two constants fold to `0`/`1`. Otherwise it
  emits `if a rel b goto _` (truelist) and `goto _` (falselist).
- **`B1 && B2`**: at `&&`, `to_cond(B1)` and record `M = nextquad()`. At the
  end: `to_cond(B2)`, `backpatch(B1.true, M)`, result
  `true = B2.true`, `false = B1.false ∪ B2.false`.
- **`B1 || B2`**: mirror image — `backpatch(B1.false, M)`,
  `true = B1.true ∪ B2.true`, `false = B2.false`.
- **`!B`**: folds a constant; otherwise `to_cond` and **swap** the lists.
  `!` never emits code of its own.

### 8.7 Unary, address, dereference

- `-x` → `t = -x` (folded for constants; for float literals the sign is
  added textually). `+x` is a no-op after the arithmetic check. `~x` needs
  integral.
- `&e` (`address_of_expr`): needs an lvalue (or a function name). Arrays give
  their decayed type (see §15). For `LV_DEREF` (`&*p`, `&ref`) no code — the
  pointer *is* the address.
- `*e` (`deref_expr`): makes `e` a value, requires a pointer, returns an
  `LV_DEREF` lvalue (no load yet). `*fp` on a function pointer yields a
  function designator (`LV_DEREF` with function type) that can be called.
  `*v` on `void*` is an error.

### 8.8 Increment and decrement: `incdec`

Needs a modifiable scalar lvalue. Step: `1`, `1.0` for floats, pointee size
for pointers.

| Form | Variable (`LV_NAME`) | Other lvalue |
|:--|:--|:--|
| `++x` | `x = x + 1` → value `x` | `t1 = load; t2 = t1 + 1; store t2` → value `t2` |
| `x++` | `t = x; x = x + 1` → value `t` | same quads → value `t1` (old) |

### 8.9 Assignment: `assign_expr`

- `check_modifiable`: must be an lvalue, not an array, function, or jump form.
- `=`: `assign_value(rhs, lhs.type)` then `store`.
- Compound `op=`: copy the lhs `ExprAttr`, run `arith_binary(op, copy, rhs)`
  (the copy is loaded; the original location is reused for the store, so an
  index like `a[f()] += 1` is computed once), convert, `store`. For a plain
  variable this prints as `t1 = c + a; c = t1`.
- The assignment's own value is the stored operand (`LV_NONE`), so
  `a = b = 5` works.

### 8.10 Members and subscripts — offset composition

Both refine a location instead of loading:

| Base | `.f` (offset k) | `[i]` on an array (scaled offset s) |
|:--|:--|:--|
| `LV_NAME x` | `LV_INDEX x, k` | `LV_INDEX x, s` |
| `LV_INDEX x, o` | `LV_INDEX x, o + k` | `LV_INDEX x, o + s` |
| `LV_DEREF p` | `LV_DEREF (p + k)` | `LV_DEREF (p + s)` |
| `LV_NONE` struct (e.g. a call result in temp t) | treated as `LV_NAME t` | – |

`add_offsets` folds literal sums and skips `+ 0`, so `box.corner.x` is a
single `box[4]` and `m[1][2]` is `m[20]`.

`->` first makes the base a value (the pointer), checks it points to a
struct/union, then proceeds as `LV_DEREF`. Subscripting a **pointer** (not
an array) also makes it a value and becomes `LV_DEREF (p + s)` — this is how
`argv[i]` and `int(*)[3]` rows work.

### 8.11 The conditional operator `c ? a : b`

```yacc
logical_or_expr T_QUESTION { to_cond($1); $<ival>$ = nextquad(); }
  expr T_COLON { $<tern>$ = ternary_mid($4); }
  conditional_expr { $$ = ternary_end(...); }
```

```
      c's jumps          (true → M1, false → F)
M1:   …code for a…
      t = a              ← value_quad
      goto END           ← skip
F:    …code for b…
      t = b
END:
```

The problem: the result type depends on **both** arms, but `t = a` must be
emitted before `b` is even parsed. Solution: `ternary_end` computes the
common type and **rewrites `value_quad` in place** into `t = (float) a` (or
a folded literal like `2.0`) if `a` needs widening. Quads are mutable until
printing, so this is safe. `t` is assigned on both paths — the one place a
temp has two definitions.

### 8.12 Calls: `call_expr`

The arguments' own code is emitted while they are parsed. At the `)`:

1. **Built-ins** (`printf`, `scanf`, `malloc`, `free`, only if the user did not
   declare a function with that name): each argument is made a value
   (strings become `.strN`) and passed as-is. Return types: `printf`/`scanf`
   int, `malloc` `void*`, `free` void.
2. **User functions** (`is_funcset`): `resolve_overload` picks one overload,
   then `convert_args`.
3. **Through a pointer** (`fp(…)` or `(*fp)(…)`): signature from the pointer
   type, arity check, `convert_args`, `icall`.

Then `param` per argument **left to right**, then `t = call f@sig, n` (no `t`
for void).

**Overload resolution** (`arg_rank` / `resolve_overload`):

| Argument vs parameter | Rank |
|:--|:--|
| identical type (after decay) | 0 exact |
| arithmetic ↔ arithmetic | 1 conversion |
| pointer ↔ `void*`, constant `0` → pointer | 1 conversion |
| function name whose overload matches a function-pointer parameter | 0 |
| reference parameter: lvalue of the same type | 0, else not viable |
| anything else | not viable |

A candidate's score is its **worst** argument rank. The unique best score
wins; a tie is *call of overloaded 'f' is ambiguous*; no viable candidate is
*no matching function*. With a single candidate the message is specific
(argument count, or which argument has which bad type).

**References in calls.** A reference parameter receives the argument's
address (`t = &value; param t`). If the argument is itself a reference
(`LV_DEREF ref`), its address is just `ref` — no quad.

---

## 9. Translating statements: backpatching

### 9.1 Conventions

- Every statement returns a **nextlist**: jumps that must go to "whatever
  comes after this statement". A statement that cannot fall through
  (`break`, `return`, `goto`) returns an empty list; straight-line code also
  returns an empty list (it falls through naturally).
- `M : %empty { $$ = nextquad(); }` records a position.
- `N : %empty { $$ = makelist(emit_goto()); }` emits a jump to be patched.
- `cond : expr { to_cond($1); }` puts a condition in jump form *before* the
  next `M` records a position.

### 9.2 Statement sequences

```yacc
stmt_list : stmt_list M stmt { backpatch($1, $2); $$ = $3; }
```

The previous statement's dangling jumps go to the start of the next one.

### 9.3 The statements

**if** — `if (B) M S`: `backpatch(B.true, M)`;
`next = B.false ∪ S.next`.

**if-else** — `if (B) M1 S1 else N M2 S2`:
`backpatch(B.true, M1)`, `backpatch(B.false, M2)`;
`next = S1.next ∪ N ∪ S2.next`. `N` is placed **after** `else` (not before
it) so the dangling-else decision remains a shift/reduce choice resolved by
precedence, rather than a reduce/reduce conflict.

**while** — `while M1 (B) M2 S`:
```
M1: B          true → M2, false → exit
M2: S          S.next → M1, continue → M1
    goto M1
```

**until** — identical to `while` with B's true and false lists swapped.

**do-while** — `do M1 S while M2 (B);`: `S.next → M2`, `B.true → M1`,
`continue → M2`, `next = B.false ∪ breaks`. `do … until` swaps the lists.

**for** — `for (init; M1 B; M2 incr N) M3 S`:
```
    init
M1: B          true → M3, false → exit
M2: incr
N:  goto M1
M3: S          S.next → M2, continue → M2
    goto M2
```
The increment is written before the body in the source, so it is emitted
there and reached by jumps. An omitted condition is "always true": a single
`goto _` in the truelist (patched to M3). The whole `for` has its own scope.

**break / continue** — `g_fn.jumps` is a stack of `JumpCtx {is_switch,
breaks, continues}`. `break` adds a `goto _` to the innermost context;
`continue` to the innermost **loop** (skipping switches). The loop patches
`continues` to its continue point and returns `breaks` in its nextlist.

**switch**
```
    t = e            (copied once unless already a temp or constant)
    goto TEST
L1: body of case 1   ← falls through into the next body
L2: body of case 2
    goto END         ← end_jump (so the last body skips the tests)
TEST:
    if t == 1 goto L1
    if t == 2 goto L2
    goto LD          (only if there is a default)
END:                 (no default: falling off the tests reaches END)
```
Each `case` records `(value, nextquad())` at its colon; a case body's own
nextlist is patched to the next quad (the next body). `next = end_jump ∪
breaks`. Checked: integer operand, constant labels, no duplicates, one
default.

**goto / labels** — `g_fn.labels` maps a name to a quad. `goto L` to a known
label is patched immediately; to an unknown one it waits in
`pending_gotos[L]` and is patched by `define_label`. Leftovers are reported
at the end of the function.

**return** — `return_stmt` checks void vs value and converts with
`assign_value`.

### 9.4 Ending a function: `end_function`

A final `return` (`return 0` for `main`) is emitted if control can reach the
end: the body's nextlist is non-empty, or the body is empty, or the last
quad is not a `return`, or some jump targets the position just past the
end (a label or `break` at the very end). Then the nextlist is patched to
it. This guarantees **no jump ever points outside its function**.

---

## 10. Declarations, functions, structs, enums, typedefs

### 10.1 Declarators are collected, then built

C declarators are inside-out (`int *(*fp)(int)`), so the grammar fills a
`DeclInfo` bottom-up:

| Field | Set by |
|:--|:--|
| `name`, `line` | the identifier |
| `pointer_depth` | `*`s outside parentheses |
| `group_pointer`, `grouped` | `( declarator )` moves the inner `*`s here |
| `is_reference` | `&` |
| `dims` | each `[N]` (must be a positive constant), `[]` → -1 |
| `is_function` / `is_func_ptr`, `params` | `( params )` — a function pointer if there was a parenthesized `*` |

`mark_function` turns `(void)` into no parameters. `build_type(base, d)`
combines the declaration's base type with the shape:

- function / function pointer → `func_info` with return type
  `base + pointer_depth`;
- no dims → add pointers (to `outer_pointer` if the base is a typedef'd
  array: `Buffer *p` is `int(*)[3]`);
- dims → array of (base + pointers); `(*p)[3]` sets `outer_pointer`;
  typedef'd array dims are appended after the declarator's dims.

The base type comes from `g_current_decl_type`, set by
`declaration_specifiers`. A parameter list contains its own
`declaration_specifiers`, so the outer value is pushed on
`g_decl_type_save_stack` at `(` and restored at `)` — otherwise
`int f(char c), x;` would make `x` a `char`.

**Parameters** (`make_param`): arrays decay (`char *argv[]` → `char**`,
`int m[][3]` → `int(*)[3]`), functions become function pointers.

### 10.2 `declare_object` — the decision tree

```
declarator d with base type B
├─ B.is_typedef            → insert SK_TYPEDEF (no code)
├─ inside a struct body    → add_member
├─ function type           → declare_function (prototype)
├─ void / unsized-without-initializer / incomplete / reference-without-init → error
├─ already declared in this scope → "redeclaration"
└─ object:
   ├─ global              → unique_global_name, .data entry (init "0")
   ├─ static local        → <func>.<name>,       .data entry ("static local")
   └─ local               → unique_local_name,   FuncRecord.locals
```

### 10.3 Functions

`declare_function(name, type, line, defining)`:

- a global non-function with the same name → *redeclared as a different
  kind of symbol*;
- same mangled name already present: different return type → *functions
  that differ only in their return type cannot be overloaded*; defined twice →
  *redefinition*; otherwise just update `defined`;
- new signature → new overload.

`begin_function` (mid-rule action before the body) declares the function
**before** parsing the body — that is what makes recursion work — then resets
`g_fn` and the temp counter, starts a `FuncRecord`, pushes the function scope
and inserts the parameters. `end_function` is described in §9.4.

### 10.4 Structs, unions, classes

`composite_begin` creates/reset the layout keyed `"struct Point"` and pushes
it on `g_composite_stack`; member declarations then go through
`declare_object` → `add_member`. `composite_end` computes the layout:

```
struct: offset = round_up(offset, align(member)); member.offset = offset; offset += size
union:  member.offset = 0;                       size = max(size)
total size = round_up(size, max alignment)
```

Example: `struct Rect { char tag; struct Point corner; double area; }` →
`tag @0`, `corner @4` (aligned to 4), `area @16` (aligned to 8), size 24.

`struct Node *next` inside `struct Node` works because a pointer's size is
8 regardless of the incomplete pointee. `struct Z;` / `struct Z *p`
(`composite_ref`) creates an incomplete layout entry; using `struct Z` by
value or through `->` reports *incomplete type*.

Classes use the same machinery. A member function body pushes an empty
sentinel `""` on `g_composite_stack` so its local declarations are not
mistaken for members; the function itself is reported as unsupported.

### 10.5 Enums

Enumerators are inserted into the **enclosing** scope as `SK_ENUM_CONST`.
`g_enum_next` holds the next implicit value (reset per enum); `= expr` must
be a constant. Every use becomes the literal value (`BLUE` → `6`), so
enumerators work in array sizes and `case` labels. Enum variables are 4-byte
integers; assigning any integer to them is allowed, as in C.

### 10.6 Typedefs

`typedef` is a storage-class flag on the base type; `declare_object` stores
the fully built type under `SK_TYPEDEF`. Using the alias
(`type_specifier : T_TYPE_NAME`) copies that type, so pointer, array,
struct and function-pointer aliases all compose with further declarators.

---

## 11. Initializers

### 11.1 Two halves

```yacc
init_declarator : declarator T_ASSIGN { $<init_ctx>$ = init_begin($1); } initializer { init_finish(...); }
```

`init_begin` declares the object **before** its initializer is parsed (so
`int x = x;` refers to the new `x`, as in C), decides whether the initializer
must be constant (globals and statics), sets `g_const_init`, and records
`mark = nextquad()`.

The initializer itself is an `InitNode` tree (`expr` leaf, or `is_list` with
`items`). Leaf expressions are put in value form as they are reduced (so jump
code cannot leak), but loads are deferred until the store.

### 11.2 Flattening: memory-order slots with brace elision

`flatten_init` turns a tree into `InitSlot {offset, type, expr}` entries, one
per scalar, in memory order:

- A **nested list** initializes one sub-object (`{{1,2,3},{4}}`).
- A **plain value where an aggregate is expected** triggers *brace
  elision*: the sub-object's elements are taken from the *same* list
  (`int flat[2][2] = {1,2,3,4}`).
- A struct-typed value initializes a whole struct member.
- Missing elements become `expr == nullptr` slots (**zero-fill**).
- An omitted outer extent (`int b[] = {1,2,3}`) is counted and written back
  into the type.
- A string for a char array becomes one slot per character plus `'\0'`
  (`char s[5] = "hello"` exactly fits without the terminator; longer is an
  error).
- Unions initialize their first member only.

### 11.3 Locals vs constants

| | Local (`init_local`) | Global / static (`init_finish` constant path) |
|:--|:--|:--|
| Scalar | `x = v` after `assign_value` | `.data` init text |
| Aggregate | one `x[off] = v` per slot (zeros included) | `{1, 2, 3}`, trailing fill trimmed; char arrays as `"text"` |
| Reference | `r = &x` (or `r = <address>`) | `&global` |

**How "constant" is enforced.** While `g_const_init` is set,
`&<static object>` produces the address constant `&name` instead of
emitting `t = &name`. After the initializer, any quad emitted since `mark`
means something non-constant ran: the quads are discarded
(`g_code.resize(mark)`) and *initializer element is not constant* is
reported. A bare global name (`int b = a;`) emits nothing, so each leaf is
also checked with `const_value_text` (constants, float literals, strings,
`&name`, function names only).

---

## 12. Errors: detection, propagation, reporting

- **Error expressions.** `error_expr` returns an `ExprAttr` with
  `BK_ERROR`. `bad(e)` is checked at the top of every helper, which then
  returns another error expression **without a message**. `same_type`
  treats error types as equal. Net effect: one mistake → one message.
- **Messages** are collected by `sem_error(line, fmt, …)` in order of
  detection (source order, except "label used but not defined", reported
  at the end of its function). `ts(type)` formats types; it uses a
  `std::deque` because several `ts()` results appear in one call and a
  `vector` would reallocate and invalidate earlier `c_str()` pointers.
- **Reporting order in `main`:** lexical errors (fatal) → syntax errors →
  semantic errors. Only the first non-empty category is printed, with exit
  code 1, and no file is written.
- **Syntax error recovery** (`error ';'`, `error '}'` rules) lets several
  syntax errors be reported in one run; actions after recovery may run on
  partial state, which is harmless because output is suppressed.

---

## 13. Annotated walkthrough of a real program

```c
struct Pair { char tag; int v[2]; };
int total(struct Pair *p, int n) {
    int s = 0;
    int i = 0;
    while (i < n && p->v[i] > 0) {
        s += p->v[i];
        if (s > 100) break;
        i++;
    }
    return s;
}
int main() {
    struct Pair q = {'a', {3, 4}};
    return total(&q, 2);
}
```

```
.types
  struct Pair: size 12 { tag:char @0, v:int[2] @4 }
```
`tag` at 0; `v` needs 4-byte alignment → offset 4; size 4+8 = 12.

```
func_begin total@PS4Pairi            ← P S4Pair (struct Pair*), i (int)
  params: p:struct Pair*, n:int
  locals: s:int, i:int
  0: s = 0
  1: i = 0
```
Two scalar initializers: `assign_value` + `x = v`.

```
  2: if i < n goto 4                 ← while: M1 = 2; relational → truelist [2]
  3: goto 22                         ←                              falselist [3]
```
`&&` mid-rule: `to_cond` (already jump form), `M = 4`.

```
  4: t1 = p + 4                      ← p->v: LV_DEREF(p + 4)
  5: t2 = i * 4                      ← [i] on an array: scale by 4
  6: t3 = t1 + t2                    ←   LV_DEREF(t1 + t2)
  7: t4 = *t3                        ← '>' mid-rule make_rvalue → load
  8: if t4 > 0 goto 10
  9: goto 22
```
`&&` result: `backpatch([2], 4)`; true = [8]; false = [3, 9]. The `while`
then patches `true [8] → M2 = 10`; `false [3, 9]` becomes the loop's exit.

```
  10: t5 = p + 4                     ← s += p->v[i]: rhs location computed again
  11: t6 = i * 4                     ←   (each source occurrence is evaluated;
  12: t7 = t5 + t6                   ←    no common-subexpression elimination)
  13: t8 = *t7
  14: t9 = s + t8                    ← compound: copy of lhs + rhs
  15: s = t9                         ← store
  16: if s > 100 goto 18
  17: goto 19                        ← if's nextlist [17] → patched to next stmt (19)
  18: goto 22                        ← break: appended to the loop's breaks
  19: t10 = i                        ← i++ (post): old value kept in t10 (unused)
  20: i = i + 1
  21: goto 2                         ← while: goto M1
  22: return s                       ← loop next = false [3, 9] ∪ breaks [18]
func_end total@PS4Pairi
```

```
func_begin main
  locals: q:struct Pair
  23: q[0] = 'a'                     ← flatten: tag @0
  24: q[4] = 3                       ← v[0] @4 (nested braces for the array)
  25: q[8] = 4                       ← v[1] @8
  26: t1 = &q                        ← argument &q
  27: param t1                       ← params left to right
  28: param 2
  29: t2 = call total@PS4Pairi, 2    ← overload resolved, mangled name
  30: return t2
func_end main
```

Things to notice: no jump ever needs a second pass; `i++` and `s +=` show
the deliberately naive code that a later optimization stage would clean up.

---

## 14. Edge-case catalog

| Situation | Behaviour | Mechanism |
|:--|:--|:--|
| `int x; { int x; }` | inner becomes `x.1` | `unique_local_name` |
| user variable named `t3` | renamed `t3.1` | temp-like names are reserved |
| local named like a global | renamed (`counter.1`) | `.data` names count as taken |
| two static locals named `n` in one function | `f@v.n`, `f@v.n.1` | `unique_static_name` |
| `int x = x;` | accepted (C semantics) | declared before initializer |
| `(a < b) + (c < d)` | left converted to `t=1/t=0` before right's code | mid-rule `make_rvalue` |
| `a < b;` as a statement | both lists flow to the next statement | `expr_stmt` nextlist = true ∪ false |
| condition as function argument | converted per argument | `argument_expr_list` calls `to_value` |
| `while (1)` / `for (;;)` | single unconditional jump | constant / empty condition |
| `continue` in a `switch` in a loop | goes to the loop | context stack skips switches |
| `continue` in a `switch` with no loop | error (gcc agrees) | |
| consecutive `case 2: case 3:` | both labels point at the same quad | labels emit no code |
| `switch` without `default` | falls off the test chain to the end | layout puts tests last |
| label at the very end of a function | final `return` emitted, label points to it | `end_function` scan |
| void function without `return` | implicit `return` | `end_function` |
| `main` falling off its end | `return 0` | `end_function` |
| `a[f()] += 1` | index computed once | compound assignment reuses the lvalue |
| `&arr[0]`, `box.corner.x` | offsets folded (`&arr`, `box[4]`) | `add_offsets` |
| `f().x` (struct-returning call) | `t1 = call …; t2 = t1[off]` | `LV_NONE` struct treated as a name |
| `op = add` with overloaded `add` | picks the overload matching `op`'s type | `assign_value` funcset branch |
| `apply(mul, 6)` | `param &mul@ii` | `arg_rank` / `assign_value` |
| `fp(…)` vs `(*fp)(…)` | both `icall fp, n` | `deref_expr` makes a function designator |
| passing a reference variable to a reference parameter | `param ref` (no quad) | `address_of_object` on `LV_DEREF` |
| same string literal twice | one `.strN` | `intern_string` |
| `char s[] = "hi"` | 3 byte stores, no `.data` entry | lazy interning |
| `int b[] = {1,2,3}` | type becomes `int[3]` (locals line updated too) | `flatten_aggregate` writes the dim |
| `int m[2][2] = {1,2,3,4}` | brace elision | `init_element` |
| `int a[4] = {5, 6}` | `a[8] = 0`, `a[12] = 0` | zero-fill slots |
| `static int *slot = &cache[0];` | `.data` init `&main.cache` | `g_const_init` + folded offset 0 |
| `int g2 = g1 + 1;` (globals) | error: not constant | quads since `mark` |
| `struct Node { struct Node *next; }` | allowed | pointers are size 8 |
| `int table[BLUE];` | `int[6]` | enumerators are constants |
| `typedef int Buffer[3]; Buffer *p;` | `int(*)[3]` | `outer_pointer` |
| `int (*op)(int,int)` vs `int *op(int,int)` | pointer vs function prototype | `grouped` + `group_pointer` |
| `int f(void)` | no parameters | `mark_function` |
| `void k(int); void k(int&); k(x);` | ambiguous | both overloads rank 0 |
| `1 / 0` | not folded, emitted | `fold_int` refuses |
| `char c = 300;` | accepted, no cast | char/int share a class |
| multiple semantic errors | all reported, cascades suppressed | error expressions |

---

## 15. Known limitations and leniencies

Not supported by the language/grammar: casts, `sizeof`, comma operator,
preprocessor, `long`/`short`/`unsigned`/`const`/`bool`, octal/binary/hex-float
literals and suffixes, adjacent string concatenation, unnamed pointer
parameters (`int f(char *)`), pointer-to-function-pointer, functions returning
function pointers or references, classes' member functions and `this`.

Deliberate simplifications:

- **`&array`** yields a pointer to the first element (`int*`) rather than
  `int(*)[N]`, so `int *p = &arr;` is accepted (gcc warns).
- **Built-in calls are unchecked**: `free(5)` and `printf(5)` are accepted
  because built-ins have no parameter types.
- **Integer literals are not range-checked** (`99999999999`).
- **Tags share one global namespace** (a struct defined inside a function is
  visible everywhere).
- **Global/static initializers** accept only constants, string literals,
  `&name` and function names (not `&arr[1]`).
- **No optimization**: repeated address computations, unused post-increment
  temps and jumps to jumps are left in place on purpose.

Accepted because they are legal C (at most warnings): falling off a non-void
function, reading an uninitialized variable, mixing enum types, `void*`
conversions in both directions, `1 / 0` with constants.

---

## 16. Testing, and how to extend the generator

**Tests** live in `tests/ir/`:

- `valid/NN_*.c` + `expected/valid/NN_*.ir` — the output must match exactly.
  The expected files were written **by hand from the rules in this document**
  before running the generator; a mismatch means either the generator or the
  derivation is wrong, and it is investigated, never blindly copied.
- `invalid/NN_*.c` + `expected/invalid/NN_*.txt` — must exit non-zero, write
  no file, and print exactly the expected errors.
- `scripts/run_ir_tests.sh` runs both; `make test-ir` / `./run.sh --ir`.

**Adding a feature — checklist:**

1. **Lexer/grammar:** new tokens in `ir_lexer.l` and `%token`; new rules in
   `ir.y`. Rebuild and confirm **0 conflicts**
   (`bison -Wcounterexamples src/ir/ir.y`).
2. **Types:** if it is a new kind of type, extend `TypeInfo` and *every*
   function in `semantic_types.h` (`same_type`, `sizeof_type`,
   `type_to_string`, `mangle_code`, `decay`, …).
3. **Type rule first:** in the helper, check operands and return
   `error_expr` with one `sem_error` on failure; return early on `bad()`.
4. **Then emit:** use `rval` / `store` / `address_of_object`; never load an
   lvalue yourself. For control flow, return lists and let the enclosing
   rule backpatch; never patch to a guessed index.
5. **New quad op?** Add it to `quad_to_string` with a name that does not
   collide with an existing operator.
6. **Tests:** derive the expected IR by hand, add a valid and an invalid
   test, run the whole suite.

---

## 17. Glossary

| Term | Meaning |
|:--|:--|
| **3AC / quad** | an instruction with at most one operator: `op, a1, a2, res` |
| **backpatching** | emitting jumps with unknown targets and filling them in later |
| **truelist / falselist** | jumps to take when a condition is true / false |
| **nextlist** | jumps that must go to the code after a statement |
| **M / N markers** | empty rules that record `nextquad()` / emit a pending `goto` |
| **jump form** | an expression represented only by its truelist/falselist |
| **lvalue kind** | where an expression's object lives (`LV_NAME`, `LV_INDEX`, `LV_DEREF`) |
| **decay** | array → pointer to first element; function → function pointer |
| **brace elision** | initializing a sub-aggregate from the enclosing list without inner braces |
| **mangling** | encoding parameter types into a function's IR name |
| **funcset** | a function name whose overload has not been chosen yet |
| **address constant** | an operand that is an address without code: `.strN`, `&f@sig`, `&global` in initializers |
| **static storage** | globals and `static` locals, stored in `.data` |
| **lexer hack** | the lexer consulting the symbol table to recognize typedef names |
