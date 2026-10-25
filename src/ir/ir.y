/* ir.y — Bison grammar for THECompiler's IR generation phase.
 *
 * One pass does three jobs: parsing, semantic analysis (scopes + type
 * checking, type_check.h) and three-address-code generation (ir_gen.h).
 * Every action type-checks its operands before it emits anything; any
 * semantic error suppresses the IR file.
 *
 * Control flow uses backpatching (Dragon book §6.6–6.7): jumps are emitted
 * with blank targets and carried in truelist / falselist / nextlist until the
 * target is known. M records nextquad(); N emits "goto _" and yields its list.
 *
 * Simplifications:
 *   - No C-style casts, sizeof, or comma operator (as in the parser).
 *   - Floating literals have type float (there are no suffixes).
 *   - &array yields a pointer to the first element (like the array's decay)
 *     rather than a pointer to the whole array.
 *   - Classes are excluded by the spec: their data members are laid out
 *     like a struct, member functions and `this` are rejected.
 */

%code requires {
    #include <string>
    #include <vector>
    #include "type_check.h"

    struct ParamDecl {
        TypeInfo type;
        const char* name = nullptr;
        int line = 0;
    };

    // Declarator shape, collected bottom-up; build_type() combines it with
    // the declaration's base type.
    struct DeclInfo {
        const char* name = nullptr;
        int line = 0;
        int pointer_depth = 0;      // '*'s outside parentheses
        int group_pointer = 0;      // '*'s inside "( ... )", as in (*fp)
        bool grouped = false;
        bool is_reference = false;  // after a function's (...): it returns a reference
        bool func_reference = false;    // '&' inside "( ... )" of a function pointer: (*&rfp)(...)
        int array_pointer = 0;      // parenthesized '*'s before a "[..]": (*p)[3] is 1
        std::vector<int> dims;
        bool is_function = false;
        int func_ptr_depth = 0;     // (*fp)(...) is 1, (**pp)(...) is 2
        std::vector<ParamDecl> params;
    };

    struct InitNode {
        ExprAttr* expr = nullptr;          // leaf
        std::vector<InitNode*> items;      // brace-enclosed list
        bool is_list = false;
    };

    struct InitCtx {
        SymbolInfo* sym = nullptr;
        bool constant = false;   // global/static: must be a constant initializer
        int mark = 0;            // nextquad() before the initializer
        int line = 0;
    };

    // State carried between the two halves of "c ? a : b".
    struct TernaryState {
        ExprAttr* a = nullptr;
        std::string temp;
        int value_quad = -1;     // "temp = a"; becomes a cast if b widens the type
        List skip;               // goto past the false arm
        int false_start = 0;
    };
}

%code {
    #include <cstdio>
    #include <cstdlib>
    #include <cstring>
    #include <iostream>
    #include <sstream>
    #include "common.h"
    #include "string_pool.h"

    std::vector<TokenRecord> g_tokens;
    StringPool g_string_pool;

    std::vector<std::string> g_syntax_errors;
    bool g_had_lex_error = false;
    std::vector<std::string> g_lex_errors;

    extern int yylineno;
    extern int yylex(void);
    extern FILE* yyin;
    void yyerror(const char* msg);

    ScopedSymbolTable g_symtab;
    TypeInfo* g_current_decl_type = nullptr;

    // Saved/restored around function parameter lists so nested
    // declaration_specifiers reductions don't clobber the outer type.
    std::vector<TypeInfo*> g_decl_type_save_stack;

    // Keys of the struct/union/class bodies being defined. "" marks a member
    // function body, whose declarations are locals rather than members.
    std::vector<std::string> g_composite_stack;
    int g_anon_counter = 0;
    long g_enum_next = 0;

    enum { SC_NONE, SC_STATIC, SC_TYPEDEF };

    #define TOK_LINE(i) (g_tokens[(i)].line)
    #define TOK_TEXT(i) (g_tokens[(i)].lexeme)

    // ── Declarators and types ───────────────────────────────────────────────

    static bool in_composite() {
        return !g_composite_stack.empty() && !g_composite_stack.back().empty();
    }

    static TypeInfo build_type(const TypeInfo& base_in, const DeclInfo& d) {
        TypeInfo base = base_in;
        base.is_static = base.is_typedef = false;
        if (base.is_error()) return base;

        // A typedef'd reference (typedef int &IntRef) can only be used as is.
        if (base.is_reference && !d.is_function && !d.func_ptr_depth) {
            const char* what = !d.dims.empty() ? "array of references"
                             : (d.pointer_depth || d.group_pointer) ? "pointer to reference"
                             : d.is_reference ? "reference to reference" : nullptr;
            if (what) {
                sem_error(d.line, "declaration of '%s' as %s", d.name, what);
                return make_basic(BK_ERROR);
            }
        }

        if (d.is_function || d.func_ptr_depth) {
            TypeInfo ret = base;
            for (int i = 0; i < d.pointer_depth; i++) ret = pointer_to(ret);
            ret.is_reference = base.is_reference || d.is_reference;
            if (ret.is_array()) {
                sem_error(d.line, "function '%s' cannot return an array", d.name);
                return make_basic(BK_ERROR);
            }
            if (ret.is_reference && ret.is_void()) {
                sem_error(d.line, "function '%s' cannot return a reference to void", d.name);
                return make_basic(BK_ERROR);
            }
            std::vector<TypeInfo> ps;
            for (const auto& p : d.params) ps.push_back(p.type);
            TypeInfo t;
            t.make_function(ret, ps);
            t.func_ptr_depth = d.func_ptr_depth;
            t.is_reference = d.func_reference;
            if (!d.dims.empty()) {           // int (*ops[4])(int), int (*(*p)[4])(int)
                t.make_array(d.dims);
                t.outer_pointer = d.array_pointer;
            }
            return t;
        }

        // A typedef'd function or function pointer as the base: binop *pp.
        if (base.func_info) {
            TypeInfo t = base;
            int ptrs = d.pointer_depth + d.group_pointer - d.array_pointer;
            if (base.array_info && (ptrs || d.array_pointer)) {
                sem_error(d.line, "declarator '%s' over an array-of-function-pointers type is not supported", d.name);
                return make_basic(BK_ERROR);
            }
            t.func_ptr_depth += ptrs;
            if (!d.dims.empty()) {
                if (t.func_ptr_depth == 0) {
                    sem_error(d.line, "declaration of '%s' as array of functions", d.name);
                    return make_basic(BK_ERROR);
                }
                std::vector<int> dims = d.dims;   // binop table[4]; FnTable grid[2] (FnTable an array)
                if (base.array_info)
                    dims.insert(dims.end(), base.array_info->dims.begin(), base.array_info->dims.end());
                t.make_array(dims);
                t.outer_pointer = d.array_pointer;    // binop (*p)[4]
            }
            if (d.is_reference && t.is_function()) {
                sem_error(d.line, "reference to function '%s' is not supported", d.name);
                return make_basic(BK_ERROR);
            }
            t.is_reference = d.is_reference;
            return t;
        }

        // Declarator dims wrap the base type's own (typedef) dims; '*'s inside
        // parentheses point at the whole array: int (*p)[3].
        TypeInfo t = base;
        t.is_reference = base.is_reference || d.is_reference;
        if (base.outer_pointer > 0 && (d.pointer_depth || d.group_pointer || !d.dims.empty())) {
            sem_error(d.line, "declarator '%s' over a pointer-to-array type is not supported", d.name);
            return make_basic(BK_ERROR);
        }
        if (d.dims.empty()) {
            int ptrs = d.pointer_depth + d.group_pointer;
            if (base.array_info) t.outer_pointer += ptrs;   // Buffer *p: pointer to the array
            else t.pointer_depth += ptrs;
            return t;
        }
        if (base.array_info && d.pointer_depth > 0) {
            sem_error(d.line, "array of pointers to arrays '%s' is not supported", d.name);
            return make_basic(BK_ERROR);
        }
        std::vector<int> dims = d.dims;
        if (base.array_info)
            dims.insert(dims.end(), base.array_info->dims.begin(), base.array_info->dims.end());
        t.pointer_depth += d.pointer_depth;
        t.make_array(dims);
        t.outer_pointer = d.group_pointer;
        return t;
    }

    // direct_declarator "(" params ")": a function, or with a parenthesized
    // pointer, a function pointer.
    static void mark_function(DeclInfo* d, std::vector<ParamDecl> params) {
        if (params.size() == 1 && params[0].type.is_void() && !params[0].name) params.clear();
        for (const auto& p : params)
            if (p.type.is_void())
                sem_error(p.line, "parameter '%s' has void type", p.name ? p.name : "");
        if (d->is_function || d->func_ptr_depth)
            sem_error(d->line, "function '%s' cannot return a function", d->name);
        if (d->grouped && d->group_pointer > 0) {
            // Each '*' in (**pp) is one level; those before a "[..]" point at
            // the array instead: (*(*p)[4]) is a pointer to 4 function pointers.
            d->func_ptr_depth = d->group_pointer - d->array_pointer;
            d->group_pointer = 0;
            if (d->func_ptr_depth == 0) {
                sem_error(d->line, "declaration of '%s' as pointer to array of functions", d->name);
                d->func_ptr_depth = 1;
                d->dims.clear();
                d->array_pointer = 0;
            }
        } else {
            d->is_function = true;
            if (!d->dims.empty()) {
                sem_error(d->line, "declaration of '%s' as array of functions", d->name);
                d->dims.clear();
                d->array_pointer = 0;
            }
        }
        // A '&' seen so far was inside the parentheses: (*&rfp)(int) is a
        // reference to the function pointer. One written later, as in
        // int &get(), marks the return type.
        if (d->is_reference) {
            if (d->is_function) sem_error(d->line, "reference to function '%s' is not supported", d->name);
            else d->func_reference = true;
            d->is_reference = false;
        }
        d->params = std::move(params);
    }

    // '&' applied to a declarator. Anything already subscripted would become
    // an array of references; int (&ra)[3] subscripts after the '&'.
    static void mark_reference(DeclInfo* d) {
        if (d->is_reference) {
            sem_error(d->line, "declaration of '%s' as reference to reference", d->name);
        } else if (!d->dims.empty() && !d->is_function && !d->func_ptr_depth) {
            sem_error(d->line, "declaration of '%s' as array of references", d->name);
        } else {
            d->is_reference = true;
        }
    }

    // "[n]" applied to a declarator.
    static void add_dim(DeclInfo* d, int n) {
        if (d->is_function || d->func_ptr_depth) {
            sem_error(d->line, "function '%s' returning an array or pointer to array is not supported", d->name);
            return;
        }
        if (d->group_pointer > 0 && d->array_pointer == 0) {
            if (!d->dims.empty()) {   // int (*(*ops[4])[2])(int)
                sem_error(d->line, "array of pointers to arrays '%s' is not supported", d->name);
                return;
            }
            d->array_pointer = d->group_pointer;
        }
        d->dims.push_back(n);
    }

    static ParamDecl* make_param(TypeInfo* base, DeclInfo* d) {
        auto* p = new ParamDecl;
        p->line = d ? d->line : yylineno;
        p->name = d ? d->name : nullptr;
        TypeInfo t = d ? build_type(*base, *d) : *base;
        t.is_static = t.is_typedef = false;
        if (t.is_array()) {
            t = decay(t);                  // char *argv[] -> char**, int m[][3] -> int(*)[3]
        } else if (t.is_function()) {
            t.func_ptr_depth = 1;          // int f(int) parameter -> int(*)(int)
        }
        p->type = t;
        return p;
    }

    // Enters a function in its overload set; returns its mangled name.
    static std::string declare_function(const char* name, const TypeInfo& t, int line, bool defining) {
        std::string mangled = mangle_function(name, t);
        SymbolInfo* g = g_symtab.lookup_global(name);
        if (g && g->kind != SK_FUNC) {
            sem_error(line, "'%s' redeclared as a different kind of symbol", name);
            return mangled;
        }
        if (!g) {
            SymbolInfo s;
            s.kind = SK_FUNC;
            s.type_info = t;
            s.declared_line = line;
            s.ir_name = name;
            g_symtab.insert_global(name, s);
        }
        auto& set = g_functions[name];
        for (auto& f : set) {
            if (f.mangled != mangled) continue;
            if (!same_type(f.type.return_type(), t.return_type()) ||
                f.type.return_type().is_reference != t.return_type().is_reference) {
                sem_error(line, "functions that differ only in their return type cannot be overloaded ('%s')", name);
                return mangled;
            }
            if (defining && f.defined) {
                sem_error(line, "redefinition of '%s'", name);
                return mangled;
            }
            f.defined = f.defined || defining;
            return mangled;
        }
        set.push_back({t, mangled, defining, line});
        return mangled;
    }

    static void add_member(DeclInfo* d, const TypeInfo& t, bool has_init) {
        CompositeLayout& l = g_layouts[g_composite_stack.back()];
        if (has_init) sem_error(d->line, "member '%s' cannot have an initializer", d->name);
        if (t.is_error()) return;
        if (t.is_function()) {
            sem_error(d->line, "member function '%s' is not supported (classes are excluded from IR generation)", d->name);
            return;
        }
        if (t.is_reference) { sem_error(d->line, "reference member '%s' is not supported", d->name); return; }
        if (sizeof_type(t) == 0) {
            sem_error(d->line, "member '%s' has incomplete type '%s'", d->name, ts(t));
            return;
        }
        for (const auto& m : l.members)
            if (m.name == d->name) { sem_error(d->line, "duplicate member '%s'", d->name); return; }
        l.members.push_back({d->name, t, 0});
    }

    // Declares one declarator of the current declaration. Returns the symbol
    // for objects (variables), nullptr for typedefs, functions, members and errors.
    static SymbolInfo* declare_object(DeclInfo* d, bool has_init) {
        const TypeInfo& base = *g_current_decl_type;
        TypeInfo t = build_type(base, *d);
        if (t.is_error()) return nullptr;

        if (base.is_typedef) {
            if (has_init) sem_error(d->line, "typedef '%s' is initialized", d->name);
            SymbolInfo s;
            s.kind = SK_TYPEDEF;
            s.type_info = t;
            s.declared_line = d->line;
            if (!g_symtab.insert(d->name, s)) sem_error(d->line, "redeclaration of '%s'", d->name);
            return nullptr;
        }
        if (in_composite()) { add_member(d, t, has_init); return nullptr; }
        if (t.is_function()) {
            if (has_init) sem_error(d->line, "function '%s' is initialized like a variable", d->name);
            declare_function(d->name, t, d->line, false);
            return nullptr;
        }
        if (!t.func_info && t.base_kind == BK_VOID && t.pointer_depth == 0) {
            sem_error(d->line, "variable '%s' declared void", d->name);
            return nullptr;
        }
        bool unsized = t.is_array() && t.array_info->dims[0] < 0;
        if (unsized && !has_init) {
            sem_error(d->line, "array size missing in '%s'", d->name);
            return nullptr;
        }
        if (!unsized && sizeof_type(t) == 0) {
            sem_error(d->line, "storage size of '%s' isn't known ('%s')", d->name, ts(t));
            return nullptr;
        }
        if (t.is_reference && !has_init) {
            sem_error(d->line, "reference '%s' must be initialized", d->name);
            return nullptr;
        }
        if (g_symtab.lookup_current(d->name)) {
            sem_error(d->line, "redeclaration of '%s'", d->name);
            return nullptr;
        }

        SymbolInfo s;
        s.kind = SK_VAR;
        s.type_info = t;
        s.declared_line = d->line;
        s.static_storage = !g_fn.active || base.is_static;
        if (!g_fn.active)       s.ir_name = unique_global_name(d->name);
        else if (base.is_static) s.ir_name = unique_static_name(d->name);
        else                    s.ir_name = unique_local_name(d->name);
        SymbolInfo* sym = g_symtab.insert(d->name, s);

        if (sym->static_storage) {
            std::string comment = g_fn.active ? "static local" : (base.is_static ? "static" : "");
            add_data(sym->ir_name, type_to_string(t), sizeof_type(t), "0", comment);
        } else {
            g_funcs.back().locals.push_back({sym->ir_name, type_to_string(t)});
        }
        return sym;
    }

    // ── Initializers ────────────────────────────────────────────────────────

    struct InitSlot {
        int offset;
        TypeInfo type;
        ExprAttr* expr;    // nullptr: zero-filled
    };

    static std::string zero_value(const TypeInfo& t) { return t.is_floating() ? "0.0" : "0"; }

    static bool is_char_array(const TypeInfo& t) {
        return t.is_array() && t.array_info->dims.size() == 1 &&
               t.base_kind == BK_CHAR && t.pointer_depth == 0;
    }

    static std::string char_literal(unsigned char c) {
        switch (c) {
            case '\n': return "'\\n'";
            case '\t': return "'\\t'";
            case '\r': return "'\\r'";
            case '\0': return "'\\0'";
            case '\\': return "'\\\\'";
            case '\'': return "'\\''";
            default:   return std::string("'") + (char)c + "'";
        }
    }

    static ExprAttr* char_const_expr(unsigned char c, int line) {
        ExprAttr* e = int_const_expr(c, line);
        e->type = make_basic(BK_CHAR);
        e->addr = char_literal(c);
        return e;
    }

    // "abc" or {"abc"}
    static ExprAttr* string_init(InitNode* n) {
        if (!n->is_list) return (n->expr && n->expr->is_string) ? n->expr : nullptr;
        if (n->items.size() == 1 && !n->items[0]->is_list && n->items[0]->expr->is_string)
            return n->items[0]->expr;
        return nullptr;
    }

    static bool fit_string(TypeInfo& t, const std::string& s, int line) {
        int& n = t.array_info->dims[0];
        if (n < 0) n = (int)s.size() + 1;
        else if ((int)s.size() > n) {
            sem_error(line, "initializer-string for array of %d chars is too long", n);
            return false;
        }
        return true;
    }

    static void string_slots(const TypeInfo& t, int base, const std::string& s, int line,
                             std::vector<InitSlot>& out) {
        for (int k = 0; k < t.array_info->dims[0]; k++) {
            TypeInfo ch = make_basic(BK_CHAR);
            if (k < (int)s.size())       out.push_back({base + k, ch, char_const_expr(s[k], line)});
            else if (k == (int)s.size()) out.push_back({base + k, ch, char_const_expr(0, line)});
            else                         out.push_back({base + k, ch, nullptr});
        }
    }

    static void zero_slots(const TypeInfo& t, int off, std::vector<InitSlot>& out) {
        if (t.is_array()) {
            TypeInfo et = element_type(t);
            int esz = sizeof_type(et);
            for (int k = 0; k < t.array_info->dims[0]; k++) zero_slots(et, off + k * esz, out);
        } else if (t.is_composite()) {
            const CompositeLayout* l = find_layout(t);
            size_t count = (l->kind == BK_UNION) ? std::min<size_t>(1, l->members.size()) : l->members.size();
            for (size_t i = 0; i < count; i++) zero_slots(l->members[i].type, off + l->members[i].offset, out);
        } else {
            out.push_back({off, t, nullptr});
        }
    }

    static bool flatten_aggregate(TypeInfo& t, int base, const std::vector<InitNode*>& items,
                                  size_t& pos, int line, std::vector<InitSlot>& out, bool top);

    // Initializes one sub-object of type et at offset off from items[pos...].
    static bool init_element(TypeInfo et, int off, const std::vector<InitNode*>& items,
                             size_t& pos, int line, std::vector<InitSlot>& out) {
        if (pos >= items.size()) { zero_slots(et, off, out); return true; }
        InitNode* it = items[pos];
        bool aggregate = et.is_array() || et.is_composite();
        if (it->is_list) {
            pos++;
            if (aggregate) {
                size_t p = 0;
                if (!flatten_aggregate(et, off, it->items, p, line, out, false)) return false;
                if (p < it->items.size()) { sem_error(line, "excess elements in initializer"); return false; }
                return true;
            }
            if (it->items.size() != 1 || it->items[0]->is_list) {
                sem_error(line, "invalid initializer for scalar of type '%s'", ts(et));
                return false;
            }
            out.push_back({off, et, it->items[0]->expr});
            return true;
        }
        if (et.is_composite() && !bad(it->expr) && same_type(it->expr->type, et)) {
            out.push_back({off, et, it->expr});
            pos++;
            return true;
        }
        if (aggregate)   // brace elision: the sub-object's elements come from this same list
            return flatten_aggregate(et, off, items, pos, line, out, false);
        out.push_back({off, et, it->expr});
        pos++;
        return true;
    }

    static bool flatten_aggregate(TypeInfo& t, int base, const std::vector<InitNode*>& items,
                                  size_t& pos, int line, std::vector<InitSlot>& out, bool top) {
        if (t.is_array()) {
            if (is_char_array(t) && pos < items.size() && !items[pos]->is_list && items[pos]->expr->is_string) {
                if (!fit_string(t, items[pos]->expr->str_value, line)) return false;
                string_slots(t, base, items[pos]->expr->str_value, line, out);
                pos++;
                return true;
            }
            TypeInfo et = element_type(t);
            int esz = sizeof_type(et);
            int n = t.array_info->dims[0];
            if (n < 0 && !top) { sem_error(line, "array size missing in initializer"); return false; }
            int k = 0;
            for (; n < 0 ? pos < items.size() : k < n; k++)
                if (!init_element(et, base + k * esz, items, pos, line, out)) return false;
            if (n < 0) t.array_info->dims[0] = k;
            return true;
        }
        const CompositeLayout* l = find_layout(t);
        size_t count = (l->kind == BK_UNION) ? std::min<size_t>(1, l->members.size()) : l->members.size();
        for (size_t i = 0; i < count; i++)
            if (!init_element(l->members[i].type, base + l->members[i].offset, items, pos, line, out))
                return false;
        return true;
    }

    // Lays an aggregate initializer out as scalar slots in memory order,
    // following C's brace-elision rules. Fills in an omitted outer extent.
    static bool flatten_init(TypeInfo& t, InitNode* node, int line, std::vector<InitSlot>& out) {
        if (is_char_array(t)) {
            if (ExprAttr* s = string_init(node)) {
                if (!fit_string(t, s->str_value, line)) return false;
                string_slots(t, 0, s->str_value, line, out);
                return true;
            }
        }
        if (!node->is_list) {
            if (t.is_composite()) { out.push_back({0, t, node->expr}); return true; }
            sem_error(line, "array initializer must be a brace-enclosed list");
            return false;
        }
        size_t pos = 0;
        if (!flatten_aggregate(t, 0, node->items, pos, line, out, true)) return false;
        if (pos < node->items.size()) { sem_error(line, "excess elements in initializer"); return false; }
        return true;
    }

    static ExprAttr* scalar_init(InitNode* n, int line, const TypeInfo& t) {
        if (!n->is_list) return n->expr;
        if (n->items.size() == 1 && !n->items[0]->is_list) return n->items[0]->expr;
        sem_error(line, "invalid initializer for scalar of type '%s'", ts(t));
        return nullptr;
    }

    static bool const_value_text(ExprAttr* e, const TypeInfo& t, int line, const char* name, std::string& out) {
        if (bad(e)) return false;
        if (t.is_reference) {
            TypeInfo rt = t;
            rt.is_reference = false;
            if (e->lv == LV_NAME && e->static_storage && same_type(e->type, rt)) {
                out = "&" + e->addr;
                return true;
            }
            sem_error(line, "initializer element for '%s' is not constant", name);
            return false;
        }
        bool constant = e->is_funcset || e->is_string || e->has_const || e->is_float_lit ||
                        (e->lv == LV_NONE && !e->addr.empty() && e->addr[0] == '&');
        if (!constant) {
            sem_error(line, "initializer element for '%s' is not constant", name);
            return false;
        }
        return assign_value(e, t, line, "initialization", out);
    }

    // The .data initializer text of a global/static.
    static bool const_init_text(TypeInfo& t, InitNode* node, int line, const char* name, std::string& out) {
        if (!(t.is_array() || t.is_composite())) {
            ExprAttr* e = scalar_init(node, line, t);
            return e && const_value_text(e, t, line, name, out);
        }
        if (is_char_array(t)) {
            if (ExprAttr* s = string_init(node)) {
                if (!fit_string(t, s->str_value, line)) return false;
                out = "\"" + escape_string(s->str_value) + "\"";
                return true;
            }
        }
        std::vector<InitSlot> slots;
        if (!flatten_init(t, node, line, slots)) return false;
        size_t last = slots.size();
        while (last > 0 && !slots[last - 1].expr) last--;
        out = "{";
        for (size_t i = 0; i < last; i++) {
            std::string v = zero_value(slots[i].type);
            if (slots[i].expr && !const_value_text(slots[i].expr, slots[i].type, line, name, v)) return false;
            out += (i ? ", " : "") + v;
        }
        out += "}";
        return true;
    }

    static void init_local(SymbolInfo* s, InitNode* node, int line) {
        TypeInfo& t = s->type_info;
        if (t.is_reference) {
            TypeInfo rt = t;
            rt.is_reference = false;
            ExprAttr* e = scalar_init(node, line, t);
            if (!e || bad(e)) return;
            if (e->is_cond || e->lv == LV_NONE || e->is_funcset || !same_type(e->type, rt)) {
                sem_error(line, "invalid initialization of reference '%s' of type '%s' from expression of type '%s'",
                          s->lexeme, ts(t), ts(e->type));
                return;
            }
            if (e->lv == LV_NAME) emit("addr", e->addr, "", s->ir_name);
            else                  emit("=", address_of_object(e), "", s->ir_name);
            return;
        }
        if (!(t.is_array() || t.is_composite())) {
            ExprAttr* e = scalar_init(node, line, t);
            std::string v;
            if (e && assign_value(e, t, line, "initialization", v)) emit("=", v, "", s->ir_name);
            return;
        }
        std::vector<InitSlot> slots;
        if (!flatten_init(t, node, line, slots)) return;
        for (auto& l : g_funcs.back().locals)
            if (l.first == s->ir_name) l.second = type_to_string(t);
        for (auto& sl : slots) {
            std::string v = zero_value(sl.type);
            if (sl.expr && !assign_value(sl.expr, sl.type, line, "initialization", v)) return;
            if (sl.offset == 0 && same_type(sl.type, t)) emit("=", v, "", s->ir_name);
            else emit("[]=", std::to_string(sl.offset), v, s->ir_name);
        }
    }

    static InitCtx* init_begin(DeclInfo* d) {
        auto* c = new InitCtx;
        c->line = d->line;
        c->sym = declare_object(d, true);
        c->constant = !g_fn.active || (c->sym && c->sym->static_storage);
        g_const_init = c->constant;
        c->mark = nextquad();
        return c;
    }

    static void init_finish(InitCtx* c, InitNode* node) {
        g_const_init = false;
        if (!c->constant) {
            if (c->sym) init_local(c->sym, node, c->line);
            return;
        }
        bool emitted = nextquad() != c->mark;
        g_code.resize(c->mark);          // constant initializers never leave code behind
        if (!c->sym) return;
        if (emitted) {
            sem_error(c->line, "initializer element for '%s' is not constant", c->sym->lexeme);
            return;
        }
        std::string text;
        if (!const_init_text(c->sym->type_info, node, c->line, c->sym->lexeme, text)) return;
        DataEntry* de = find_data(c->sym->ir_name);
        de->init = text;
        de->type = type_to_string(c->sym->type_info);
        de->size = sizeof_type(c->sym->type_info);
    }

    // ── struct / union / class / enum ───────────────────────────────────────

    static void composite_begin(BaseKind kind, const std::string& tag, int line) {
        std::string t = tag.empty() ? "$anon" + std::to_string(++g_anon_counter) : tag;
        std::string key = layout_key(kind, t);
        CompositeLayout& l = g_layouts[key];
        if (l.complete) sem_error(line, "redefinition of '%s'", key.c_str());
        l = CompositeLayout{};
        l.kind = kind;
        l.tag = t;
        g_composite_stack.push_back(key);
    }

    // Members are placed in order, each aligned to its own alignment; union
    // members all sit at offset 0. Size rounds up to the largest alignment.
    static TypeInfo* composite_end() {
        std::string key = g_composite_stack.back();
        g_composite_stack.pop_back();
        CompositeLayout& l = g_layouts[key];
        int off = 0, size = 0, align = 1;
        for (auto& m : l.members) {
            int a = alignof_type(m.type), s = sizeof_type(m.type);
            align = std::max(align, a);
            if (l.kind == BK_UNION) {
                m.offset = 0;
                size = std::max(size, s);
            } else {
                off = (off + a - 1) / a * a;
                m.offset = off;
                off += s;
                size = off;
            }
        }
        l.size = (size + align - 1) / align * align;
        l.align = align;
        l.complete = true;
        if (std::find(g_layout_order.begin(), g_layout_order.end(), key) == g_layout_order.end())
            g_layout_order.push_back(key);
        TypeInfo* t = new TypeInfo(make_basic(l.kind));
        t->set_composite_tag(l.tag);
        return t;
    }

    static TypeInfo* composite_ref(BaseKind kind, const std::string& tag) {
        std::string key = layout_key(kind, tag);
        if (!g_layouts.count(key)) {
            CompositeLayout l;
            l.kind = kind;
            l.tag = tag;
            g_layouts[key] = l;
        }
        TypeInfo* t = new TypeInfo(make_basic(kind));
        t->set_composite_tag(tag);
        return t;
    }

    static TypeInfo* enum_type(const std::string& tag) {
        TypeInfo* t = new TypeInfo(make_basic(BK_ENUM));
        t->set_composite_tag(tag.empty() ? "$anon" + std::to_string(++g_anon_counter) : tag);
        return t;
    }

    static void declare_enumerator(int tok, ExprAttr* value) {
        const char* name = TOK_TEXT(tok);
        int line = TOK_LINE(tok);
        long v = g_enum_next;
        if (value && !bad(value)) {
            if (value->has_const) v = value->cval;
            else sem_error(line, "enumerator value for '%s' is not an integer constant", name);
        }
        SymbolInfo s;
        s.kind = SK_ENUM_CONST;
        s.type_info = int_type();
        s.declared_line = line;
        s.enum_value = v;
        s.ir_name = name;
        if (!g_symtab.insert(name, s)) sem_error(line, "redeclaration of '%s'", name);
        g_enum_next = v + 1;
    }

    // ── Functions ───────────────────────────────────────────────────────────

    static void begin_function(TypeInfo* base, DeclInfo* d) {
        TypeInfo t = build_type(*base, *d);
        bool in_class = in_composite();
        std::string ir = d->name;
        if (!t.is_error() && !t.is_function())
            sem_error(d->line, "'%s' is defined with a body but is not a function", d->name);
        else if (in_class)
            sem_error(d->line, "member function '%s' is not supported (classes are excluded from IR generation)", d->name);
        else if (t.is_function())
            ir = declare_function(d->name, t, d->line, true);

        g_fn = FuncCtx{};
        g_fn.active = true;
        g_fn.in_class = in_class;
        g_fn.ir_name = ir;
        g_fn.ret = t.is_function() ? t.return_type() : make_basic(BK_VOID);
        if (in_class) g_composite_stack.push_back("");
        g_temp_counter = 0;

        g_funcs.push_back(FuncRecord{});
        g_funcs.back().name = ir;
        g_funcs.back().start = nextquad();
        g_symtab.push_scope(d->name);
        for (const auto& p : d->params) {
            if (!p.name) continue;
            if (g_symtab.lookup_current(p.name)) {
                sem_error(p.line, "redefinition of parameter '%s'", p.name);
                continue;
            }
            SymbolInfo s;
            s.kind = SK_VAR;
            s.type_info = p.type;
            s.declared_line = p.line;
            s.ir_name = unique_local_name(p.name);
            g_symtab.insert(p.name, s);
            g_funcs.back().params.push_back({s.ir_name, type_to_string(p.type)});
        }
    }

    // Closes the body: control that can reach the end gets a final return.
    static void end_function(List* next) {
        int start = g_funcs.back().start;
        int end = nextquad();
        bool need_return = !next->empty() || end == start || g_code[end - 1].op != "return";
        for (int q = start; q < end && !need_return; q++)
            if (g_code[q].target == end) need_return = true;
        if (need_return) {
            backpatch(*next, end);
            if (g_fn.ir_name == "main") emit("return", "0");
            else emit("return");
        }
        for (const auto& pg : g_fn.pending_gotos)
            for (const auto& use : pg.second)
                sem_error(use.second, "label '%s' used but not defined", pg.first.c_str());
        g_funcs.back().end = nextquad();
        g_symtab.pop_scope();
        if (g_fn.in_class) g_composite_stack.pop_back();
        g_fn.active = false;
    }

    // ── Expressions ─────────────────────────────────────────────────────────

    static ExprAttr* identifier_expr(int tok) {
        const char* name = TOK_TEXT(tok);
        int line = TOK_LINE(tok);
        SymbolInfo* s = g_symtab.lookup(name);
        if (!s) {
            if (is_builtin(name)) {
                ExprAttr* e = new_expr(line);
                e->is_funcset = true;
                e->func_name = name;
                e->type.make_function(builtin_return(name));
                return e;
            }
            sem_error(line, "'%s' undeclared", name);
            return error_expr(line);
        }
        ExprAttr* e = new_expr(line);
        switch (s->kind) {
            case SK_ENUM_CONST:
                return int_const_expr(s->enum_value, line);
            case SK_FUNC:
                e->is_funcset = true;
                e->func_name = name;
                e->type = g_functions[name].front().type;
                return e;
            case SK_TYPEDEF:
                sem_error(line, "unexpected type name '%s'", name);
                return error_expr(line);
            case SK_VAR:
                e->type = s->type_info;
                e->addr = s->ir_name;
                e->static_storage = s->static_storage;
                if (e->type.is_reference) {   // a reference names the object it is bound to
                    e->type.is_reference = false;
                    e->lv = LV_DEREF;
                } else {
                    e->lv = LV_NAME;
                }
                return e;
        }
        return e;
    }

    static long char_value(const char* lex) {
        if (lex[1] != '\\') return (unsigned char)lex[1];
        switch (lex[2]) {
            case 'n': return '\n';
            case 't': return '\t';
            case 'r': return '\r';
            case '0': return 0;
            case 'a': return '\a';
            case 'b': return '\b';
            case 'f': return '\f';
            case 'v': return '\v';
            default:  return (unsigned char)lex[2];
        }
    }

    static TernaryState* ternary_mid(ExprAttr* a) {
        auto* st = new TernaryState;
        st->a = a;
        make_rvalue(a);
        st->temp = new_temp();
        st->value_quad = emit("=", bad(a) ? "?" : a->addr, "", st->temp);
        st->skip = makelist(emit_goto());
        st->false_start = nextquad();
        return st;
    }

    static ExprAttr* ternary_end(ExprAttr* c, int true_start, TernaryState* st, ExprAttr* b, int line) {
        ExprAttr* a = st->a;
        make_rvalue(b);
        backpatch(c->truelist, true_start);
        backpatch(c->falselist, st->false_start);
        auto finish = [&](const std::string& bv) {
            emit("=", bv, "", st->temp);
            backpatch(st->skip, nextquad());
        };
        if (bad(a) || bad(b) || bad(c)) { finish("?"); return error_expr(line); }

        TypeInfo rt;
        const TypeInfo &ta = a->type, &tb = b->type;
        if (ta.is_arith() && tb.is_arith())                       rt = arith_result(ta, tb);
        else if (!ta.is_void() && same_type(ta, tb))              rt = ta;
        else if (ta.is_pointer() && b->has_const && b->cval == 0) rt = ta;
        else if (tb.is_pointer() && a->has_const && a->cval == 0) rt = tb;
        else {
            sem_error(line, "type mismatch in conditional expression ('%s' and '%s')", ts(ta), ts(tb));
            finish("?");
            return error_expr(line);
        }
        // The true arm's copy was emitted before b's type was known; widen it in place.
        if (needs_cast(ta, rt)) {
            Quad& q = g_code[st->value_quad];
            if (a->has_const && rt.is_floating()) q.a1 = std::to_string(a->cval) + ".0";
            else if (!a->is_float_lit) { q.op = "cast"; q.a2 = type_to_string(rt); }
        }
        finish(cast_value(b, b->addr, rt));
        return temp_expr(st->temp, rt, line);
    }

    // ── Statements ──────────────────────────────────────────────────────────

    static JumpCtx leave_loop() {
        JumpCtx c = g_fn.jumps.back();
        g_fn.jumps.pop_back();
        return c;
    }

    static void break_stmt(int line) {
        if (g_fn.jumps.empty()) { sem_error(line, "break statement not within loop or switch"); return; }
        g_fn.jumps.back().breaks.push_back(emit_goto());
    }

    static void continue_stmt(int line) {
        for (auto it = g_fn.jumps.rbegin(); it != g_fn.jumps.rend(); ++it)
            if (!it->is_switch) { it->continues.push_back(emit_goto()); return; }
        sem_error(line, "continue statement not within a loop");
    }

    // switch (e): evaluate e once, jump to the test chain emitted at the end.
    static void switch_begin(ExprAttr* e, int line) {
        SwitchCtx sc;
        if (!bad(e)) {
            make_rvalue(e);
            if (!bad(e) && !e->type.is_integral())
                sem_error(line, "switch quantity is not an integer ('%s')", ts(e->type));
            sc.value = e->has_const ? std::to_string(e->cval) : e->addr;
            if (!e->has_const && !looks_like_temp(sc.value)) {
                std::string t = new_temp();
                emit("=", sc.value, "", t);
                sc.value = t;
            }
        }
        sc.test_jump = emit_goto();
        g_fn.switches.push_back(sc);
        JumpCtx jc;
        jc.is_switch = true;
        g_fn.jumps.push_back(jc);
    }

    static void switch_case_label(ExprAttr* e, int line) {
        SwitchCtx& sc = g_fn.switches.back();
        if (bad(e)) return;
        if (!e->has_const) { sem_error(line, "case label does not reduce to an integer constant"); return; }
        for (const auto& c : sc.cases)
            if (c.first == e->cval) { sem_error(line, "duplicate case value '%ld'", e->cval); return; }
        sc.cases.push_back({e->cval, nextquad()});
    }

    static void switch_default_label(int line) {
        SwitchCtx& sc = g_fn.switches.back();
        if (sc.default_quad >= 0) { sem_error(line, "multiple default labels in one switch"); return; }
        sc.default_quad = nextquad();
    }

    static List* switch_end() {
        int end_jump = emit_goto();
        SwitchCtx sc = g_fn.switches.back();
        g_fn.switches.pop_back();
        JumpCtx jc = leave_loop();
        g_code[sc.test_jump].target = nextquad();
        for (const auto& c : sc.cases) {
            int q = emit_if(sc.value, "==", std::to_string(c.first));
            g_code[q].target = c.second;
        }
        if (sc.default_quad >= 0) emit_goto(sc.default_quad);
        return new List(merge(makelist(end_jump), jc.breaks));
    }

    static void define_label(int tok) {
        std::string name = TOK_TEXT(tok);
        if (g_fn.labels.count(name)) { sem_error(TOK_LINE(tok), "duplicate label '%s'", name.c_str()); return; }
        int q = nextquad();
        g_fn.labels[name] = q;
        auto it = g_fn.pending_gotos.find(name);
        if (it == g_fn.pending_gotos.end()) return;
        for (const auto& use : it->second) g_code[use.first].target = q;
        g_fn.pending_gotos.erase(it);
    }

    static void goto_stmt(int tok) {
        std::string name = TOK_TEXT(tok);
        int q = emit_goto();
        auto it = g_fn.labels.find(name);
        if (it != g_fn.labels.end()) g_code[q].target = it->second;
        else g_fn.pending_gotos[name].push_back({q, TOK_LINE(tok)});
    }
}

%union {
    int token_index;
    int ival;
    TypeInfo* type_info;
    DeclInfo* decl_info;
    ExprAttr* expr;
    List* list;
    std::vector<ExprAttr*>* args;
    std::vector<ParamDecl>* params;
    ParamDecl* param;
    InitNode* init;
    InitCtx* init_ctx;
    TernaryState* tern;
}

%token <token_index> T_IDENTIFIER T_TYPE_NAME T_INT_CONST T_FLOAT_CONST
%token <token_index> T_CHAR_CONST T_STRING_LITERAL

%token T_IF T_ELSE T_FOR T_WHILE T_DO T_UNTIL T_SWITCH T_CASE T_DEFAULT
%token T_BREAK T_CONTINUE T_GOTO T_RETURN

%token T_INT T_CHAR T_FLOAT T_DOUBLE T_VOID

%token T_STATIC T_STRUCT T_TYPEDEF T_ENUM T_UNION

%token T_CLASS T_PUBLIC T_PRIVATE T_PROTECTED T_THIS T_NEW T_DELETE
%token T_VIRTUAL T_FRIEND

%token T_PLUS T_MINUS T_MUL T_DIV T_MOD T_INCR T_DECR

%token T_LT T_GT T_LE T_GE T_EQ T_NE

%token T_AND T_OR T_NOT

%token T_BIT_AND T_BIT_OR T_BIT_XOR T_BIT_NOT T_LSHIFT T_RSHIFT

%token T_ASSIGN T_PLUS_ASSIGN T_MINUS_ASSIGN T_MUL_ASSIGN T_DIV_ASSIGN
%token T_MOD_ASSIGN T_AND_ASSIGN T_OR_ASSIGN T_XOR_ASSIGN
%token T_LSHIFT_ASSIGN T_RSHIFT_ASSIGN

%token T_ARROW T_DOT T_QUESTION T_COLON

%token T_SEMICOLON T_COMMA T_LBRACE T_RBRACE T_LPAREN T_RPAREN
%token T_LBRACKET T_RBRACKET

%type <type_info>    declaration_specifiers type_specifier struct_or_union_specifier enum_specifier class_specifier
%type <decl_info>    declarator direct_declarator
%type <ival>         pointer struct_or_union storage_class_specifier M
%type <list>         N stmt stmt_list stmt_list_opt compound_stmt expr_stmt selection_stmt iteration_stmt jump_stmt labeled_stmt function_body for_init
%type <expr>         primary_expr postfix_expr unary_expr multiplicative_expr additive_expr shift_expr relational_expr equality_expr and_expr exclusive_or_expr inclusive_or_expr logical_and_expr logical_or_expr conditional_expr assignment_expr expr cond for_cond
%type <args>         argument_expr_list
%type <params>       param_list
%type <param>        param_decl
%type <init>         initializer initializer_list
%type <token_index>  unary_operator assignment_operator

/* Dangling-else: prefer shift (attach else to nearest if). */
%nonassoc IFX
%nonassoc T_ELSE

%define parse.error verbose

%start program

%%

    program
    : /* empty */
    | program external_decl
    ;

    external_decl
    : function_definition
    | declaration
    | error T_SEMICOLON { yyerrok; }
    | error T_RBRACE { yyerrok; }
    ;

    function_definition
    : declaration_specifiers declarator { begin_function($1, $2); } function_body {
    end_function($4);
    }
    ;

    function_body
    : T_LBRACE stmt_list_opt T_RBRACE { $$ = $2; }
    ;

    /* ── Declarations ──────────────────────────────────────────────────────── */

    declaration
    : declaration_specifiers init_declarator_list T_SEMICOLON
    | declaration_specifiers T_SEMICOLON
    ;

    declaration_specifiers
    : type_specifier { $$ = $1; g_current_decl_type = $1; }
    | storage_class_specifier declaration_specifiers {
    $$ = $2;
    if ($1 == SC_STATIC)  $$->is_static = true;
    if ($1 == SC_TYPEDEF) $$->is_typedef = true;
    g_current_decl_type = $$;
    }
    ;

    storage_class_specifier
    : T_STATIC { $$ = SC_STATIC; }
    | T_VIRTUAL { $$ = SC_NONE; }
    | T_FRIEND { $$ = SC_NONE; }
    | T_TYPEDEF { $$ = SC_TYPEDEF; }
    ;

    type_specifier
    : T_INT { $$ = new TypeInfo(make_basic(BK_INT)); }
    | T_CHAR { $$ = new TypeInfo(make_basic(BK_CHAR)); }
    | T_FLOAT { $$ = new TypeInfo(make_basic(BK_FLOAT)); }
    | T_DOUBLE { $$ = new TypeInfo(make_basic(BK_DOUBLE)); }
    | T_VOID { $$ = new TypeInfo(make_basic(BK_VOID)); }
    | T_TYPE_NAME {
    SymbolInfo* s = g_symtab.lookup(TOK_TEXT($1));
    $$ = new TypeInfo(s ? s->type_info : make_basic(BK_ERROR));
    $$->is_typedef = false;
    }
    | struct_or_union_specifier { $$ = $1; }
    | enum_specifier { $$ = $1; }
    | class_specifier { $$ = $1; }
    ;

    struct_or_union
    : T_STRUCT { $$ = BK_STRUCT; }
    | T_UNION { $$ = BK_UNION; }
    ;

    struct_or_union_specifier
    : struct_or_union T_IDENTIFIER {
    composite_begin((BaseKind)$1, TOK_TEXT($2), TOK_LINE($2));
    } T_LBRACE member_decl_list T_RBRACE {
    $$ = composite_end();
    }
    | struct_or_union {
    composite_begin((BaseKind)$1, "", yylineno);
    } T_LBRACE member_decl_list T_RBRACE {
    $$ = composite_end();
    }
    | struct_or_union T_IDENTIFIER {
    $$ = composite_ref((BaseKind)$1, TOK_TEXT($2));
    }
    ;

    member_decl_list
    : /* empty */
    | member_decl_list declaration
    ;

    enum_specifier
    : T_ENUM T_IDENTIFIER { g_enum_next = 0; } T_LBRACE enumerator_list T_RBRACE {
    $$ = enum_type(TOK_TEXT($2));
    }
    | T_ENUM { g_enum_next = 0; } T_LBRACE enumerator_list T_RBRACE {
    $$ = enum_type("");
    }
    | T_ENUM T_IDENTIFIER {
    $$ = enum_type(TOK_TEXT($2));
    }
    ;

    enumerator_list
    : enumerator
    | enumerator_list T_COMMA enumerator
    ;

    enumerator
    : T_IDENTIFIER { declare_enumerator($1, nullptr); }
    | T_IDENTIFIER T_ASSIGN conditional_expr { declare_enumerator($1, $3); }
    ;

    class_specifier
    : T_CLASS T_IDENTIFIER {
    composite_begin(BK_CLASS, TOK_TEXT($2), TOK_LINE($2));
    } T_LBRACE class_member_list T_RBRACE {
    $$ = composite_end();
    }
    | T_CLASS {
    composite_begin(BK_CLASS, "", yylineno);
    } T_LBRACE class_member_list T_RBRACE {
    $$ = composite_end();
    }
    | T_CLASS T_IDENTIFIER {
    $$ = composite_ref(BK_CLASS, TOK_TEXT($2));
    }
    ;

    class_member_list
    : /* empty */
    | class_member_list class_member
    ;

    class_member
    : access_specifier T_COLON
    | declaration
    | function_definition
    ;

    access_specifier
    : T_PUBLIC
    | T_PRIVATE
    | T_PROTECTED
    ;

    init_declarator_list
    : init_declarator
    | init_declarator_list T_COMMA init_declarator
    ;

    init_declarator
    : declarator { declare_object($1, false); }
    | declarator T_ASSIGN { $<init_ctx>$ = init_begin($1); }
    initializer               { init_finish($<init_ctx>3, $4); }
    ;

    declarator
    : direct_declarator { $$ = $1; }
    | pointer direct_declarator { $$ = $2; $$->pointer_depth += $1; }
    | T_BIT_AND direct_declarator { $$ = $2; mark_reference($$); }
    | pointer T_BIT_AND direct_declarator { $$ = $3; mark_reference($$); $$->pointer_depth += $1; }
    ;

    pointer
    : T_MUL { $$ = 1; }
    | T_MUL pointer { $$ = 1 + $2; }
    ;

    direct_declarator
    : T_IDENTIFIER {
    $$ = new DeclInfo();
    $$->name = TOK_TEXT($1);
    $$->line = TOK_LINE($1);
    }
    | T_LPAREN declarator T_RPAREN {
    $$ = $2;
    $$->group_pointer += $$->pointer_depth;
    $$->pointer_depth = 0;
    $$->grouped = true;
    }
    | direct_declarator T_LBRACKET T_RBRACKET { $$ = $1; add_dim($$, -1); }
    | direct_declarator T_LBRACKET conditional_expr T_RBRACKET {
    $$ = $1;
    if (!bad($3) && (!$3->has_const || $3->cval <= 0)) {
    sem_error($1->line, "size of array '%s' must be a positive integer constant", $1->name);
    add_dim($$, 1);
    } else {
    add_dim($$, $3->has_const ? (int)$3->cval : 1);
    }
    }
    | direct_declarator T_LPAREN {
    g_decl_type_save_stack.push_back(g_current_decl_type);
    } T_RPAREN {
    $$ = $1;
    mark_function($$, {});
    g_current_decl_type = g_decl_type_save_stack.back();
    g_decl_type_save_stack.pop_back();
    }
    | direct_declarator T_LPAREN {
    g_decl_type_save_stack.push_back(g_current_decl_type);
    } param_list T_RPAREN {
    $$ = $1;
    mark_function($$, *$4);
    g_current_decl_type = g_decl_type_save_stack.back();
    g_decl_type_save_stack.pop_back();
    }
    ;

    param_list
    : param_decl { $$ = new std::vector<ParamDecl>{*$1}; }
    | param_list T_COMMA param_decl { $$ = $1; $$->push_back(*$3); }
    ;

    param_decl
    : declaration_specifiers declarator { $$ = make_param($1, $2); }
    | declaration_specifiers { $$ = make_param($1, nullptr); }
    ;

    initializer
    : assignment_expr {
    to_value($1);
    $$ = new InitNode;
    $$->expr = $1;
    }
    | T_LBRACE initializer_list T_RBRACE { $$ = $2; }
    | T_LBRACE initializer_list T_COMMA T_RBRACE { $$ = $2; }
    ;

    initializer_list
    : initializer {
    $$ = new InitNode;
    $$->is_list = true;
    $$->items.push_back($1);
    }
    | initializer_list T_COMMA initializer { $$ = $1; $$->items.push_back($3); }
    ;

    /* ── Statements ────────────────────────────────────────────────────────── */

    M
    : /* empty */ { $$ = nextquad(); }
    ;

    N
    : /* empty */ { $$ = new List(makelist(emit_goto())); }
    ;

    scope_enter
    : /* empty */ { g_symtab.push_block_scope(); }
    ;

    loop_enter
    : /* empty */ { g_fn.jumps.push_back(JumpCtx{}); }
    ;

    compound_stmt
    : T_LBRACE scope_enter stmt_list_opt T_RBRACE { g_symtab.pop_scope(); $$ = $3; }
    ;

    stmt_list_opt
    : /* empty */ { $$ = new List; }
    | stmt_list { $$ = $1; }
    ;

    stmt_list
    : stmt { $$ = $1; }
    | stmt_list M stmt { backpatch(*$1, $2); $$ = $3; }
    ;

    stmt
    : compound_stmt { $$ = $1; }
    | expr_stmt { $$ = $1; }
    | selection_stmt { $$ = $1; }
    | iteration_stmt { $$ = $1; }
    | jump_stmt { $$ = $1; }
    | labeled_stmt { $$ = $1; }
    | declaration { $$ = new List; }
    | error T_SEMICOLON { yyerrok; $$ = new List; }
    ;

    expr_stmt
    : T_SEMICOLON { $$ = new List; }
    | expr T_SEMICOLON {
    $$ = new List($1->is_cond ? merge($1->truelist, $1->falselist) : List{});
    }
    ;

    cond
    : expr { to_cond($1); $$ = $1; }
    ;

    selection_stmt
    : T_IF T_LPAREN cond T_RPAREN M stmt %prec IFX {
    backpatch($3->truelist, $5);
    $$ = new List(merge($3->falselist, *$6));
    }
    | T_IF T_LPAREN cond T_RPAREN M stmt T_ELSE N M stmt {
    backpatch($3->truelist, $5);
    backpatch($3->falselist, $9);
    $$ = new List(merge(merge(*$6, *$8), *$10));
    }
    | T_SWITCH T_LPAREN expr T_RPAREN {
    switch_begin($3, TOK_LINE($<token_index>1));
    } T_LBRACE scope_enter switch_case_list T_RBRACE {
    g_symtab.pop_scope();
    $$ = switch_end();
    }
    ;

    switch_case_list
    : /* empty */
    | switch_case_list switch_case
    ;

    /* A case body falls through into whatever follows it. */
    switch_case
    : T_CASE conditional_expr T_COLON {
    switch_case_label($2, TOK_LINE($<token_index>1));
    } stmt_list_opt {
    backpatch(*$5, nextquad());
    }
    | T_DEFAULT T_COLON {
    switch_default_label(TOK_LINE($<token_index>1));
    } stmt_list_opt {
    backpatch(*$4, nextquad());
    }
    ;

    iteration_stmt
    : T_WHILE M T_LPAREN cond T_RPAREN M loop_enter stmt {
    backpatch(*$8, $2);
    backpatch($4->truelist, $6);
    JumpCtx c = leave_loop();
    backpatch(c.continues, $2);
    emit_goto($2);
    $$ = new List(merge($4->falselist, c.breaks));
    }
    | T_UNTIL M T_LPAREN cond T_RPAREN M loop_enter stmt {
    backpatch(*$8, $2);
    backpatch($4->falselist, $6);
    JumpCtx c = leave_loop();
    backpatch(c.continues, $2);
    emit_goto($2);
    $$ = new List(merge($4->truelist, c.breaks));
    }
    | T_DO M loop_enter stmt T_WHILE M T_LPAREN cond T_RPAREN T_SEMICOLON {
    backpatch(*$4, $6);
    backpatch($8->truelist, $2);
    JumpCtx c = leave_loop();
    backpatch(c.continues, $6);
    $$ = new List(merge($8->falselist, c.breaks));
    }
    | T_DO M loop_enter stmt T_UNTIL M T_LPAREN cond T_RPAREN T_SEMICOLON {
    backpatch(*$4, $6);
    backpatch($8->falselist, $2);
    JumpCtx c = leave_loop();
    backpatch(c.continues, $6);
    $$ = new List(merge($8->truelist, c.breaks));
    }
    /* init; M1 cond; M2 incr N  M3 body: cond.true -> M3, body.next -> M2, N -> M1 */
    | T_FOR T_LPAREN scope_enter for_init M for_cond T_SEMICOLON M for_incr_opt N T_RPAREN M loop_enter stmt {
    backpatch(*$4, $5);
    backpatch($6->truelist, $12);
    backpatch(*$10, $5);
    backpatch(*$14, $8);
    JumpCtx c = leave_loop();
    backpatch(c.continues, $8);
    emit_goto($8);
    g_symtab.pop_scope();
    $$ = new List(merge($6->falselist, c.breaks));
    }
    ;

    for_init
    : expr_stmt { $$ = $1; }
    | declaration { $$ = new List; }
    ;

    /* An omitted condition is always true: jump straight to the body. */
    for_cond
    : /* empty */ {
    $$ = new_expr(yylineno);
    $$->is_cond = true;
    $$->truelist = makelist(emit_goto());
    }
    | expr { to_cond($1); $$ = $1; }
    ;

    for_incr_opt
    : /* empty */
    | expr {
    if ($1->is_cond) backpatch(merge($1->truelist, $1->falselist), nextquad());
    }
    ;

    jump_stmt
    : T_GOTO T_IDENTIFIER T_SEMICOLON { goto_stmt($2); $$ = new List; }
    | T_CONTINUE T_SEMICOLON { continue_stmt(TOK_LINE($<token_index>1)); $$ = new List; }
    | T_BREAK T_SEMICOLON { break_stmt(TOK_LINE($<token_index>1)); $$ = new List; }
    | T_RETURN T_SEMICOLON { return_stmt(nullptr, TOK_LINE($<token_index>1)); $$ = new List; }
    | T_RETURN expr T_SEMICOLON { return_stmt($2, TOK_LINE($<token_index>1)); $$ = new List; }
    ;

    labeled_stmt
    : T_IDENTIFIER T_COLON { define_label($1); } stmt { $$ = $4; }
    ;

    /* ── Expressions — layered precedence (no casts, no sizeof, no comma op) ── */

    primary_expr
    : T_IDENTIFIER {
    $$ = identifier_expr($1);
    }
    | T_INT_CONST {
    $$ = int_const_expr(std::strtol(TOK_TEXT($1), nullptr, 0), TOK_LINE($1));
    }
    | T_FLOAT_CONST {
    $$ = new_expr(TOK_LINE($1));
    $$->type = make_basic(BK_FLOAT);
    $$->addr = TOK_TEXT($1);
    $$->is_float_lit = true;
    }
    | T_CHAR_CONST {
    $$ = int_const_expr(char_value(TOK_TEXT($1)), TOK_LINE($1));
    $$->type = make_basic(BK_CHAR);
    $$->addr = TOK_TEXT($1);
    }
    | T_STRING_LITERAL {
    std::string lex = TOK_TEXT($1);
    $$ = new_expr(TOK_LINE($1));
    $$->type = make_basic(BK_CHAR, 1);
    $$->is_string = true;
    $$->str_value = lex.substr(1, lex.size() - 2);
    }
    | T_THIS {
    sem_error(TOK_LINE($<token_index>1), "'this' is not supported (classes are excluded from IR generation)");
    $$ = error_expr(TOK_LINE($<token_index>1));
    }
    | T_LPAREN expr T_RPAREN { $$ = $2; }
    ;

    postfix_expr
    : primary_expr { $$ = $1; }
    | postfix_expr T_LBRACKET expr T_RBRACKET {
    $$ = index_expr($1, $3, TOK_LINE($<token_index>2));
    }
    | postfix_expr T_LPAREN T_RPAREN {
    std::vector<ExprAttr*> none;
    $$ = call_expr($1, none, TOK_LINE($<token_index>2));
    }
    | postfix_expr T_LPAREN argument_expr_list T_RPAREN {
    $$ = call_expr($1, *$3, TOK_LINE($<token_index>2));
    }
    | postfix_expr T_DOT T_IDENTIFIER {
    $$ = member_expr($1, TOK_TEXT($3), false, TOK_LINE($3));
    }
    | postfix_expr T_ARROW T_IDENTIFIER {
    $$ = member_expr($1, TOK_TEXT($3), true, TOK_LINE($3));
    }
    | postfix_expr T_INCR { $$ = incdec($1, true, true, TOK_LINE($<token_index>2)); }
    | postfix_expr T_DECR { $$ = incdec($1, false, true, TOK_LINE($<token_index>2)); }
    ;

    /* Each argument is turned into a value before the next one is parsed, so
    its jump code (if any) can't skip the following arguments' code. */
    argument_expr_list
    : assignment_expr {
    to_value($1);
    $$ = new std::vector<ExprAttr*>{$1};
    }
    | argument_expr_list T_COMMA assignment_expr {
    to_value($3);
    $$ = $1;
    $$->push_back($3);
    }
    ;

    unary_expr
    : postfix_expr { $$ = $1; }
    | T_INCR unary_expr { $$ = incdec($2, true, false, TOK_LINE($<token_index>1)); }
    | T_DECR unary_expr { $$ = incdec($2, false, false, TOK_LINE($<token_index>1)); }
    | unary_operator unary_expr { $$ = unary_op(TOK_TEXT($1), $2, TOK_LINE($1)); }
    | T_NEW type_specifier { $$ = new_object(*$2, nullptr, TOK_LINE($<token_index>1)); }
    | T_NEW type_specifier T_LBRACKET conditional_expr T_RBRACKET {
    $$ = new_object(*$2, $4, TOK_LINE($<token_index>1));
    }
    | T_DELETE unary_expr { $$ = delete_object($2, TOK_LINE($<token_index>1)); }
    | T_DELETE T_LBRACKET T_RBRACKET unary_expr {
    $$ = delete_object($4, TOK_LINE($<token_index>1));
    }
    ;

    unary_operator
    : T_BIT_AND { $$ = $<token_index>1; }
    | T_MUL { $$ = $<token_index>1; }
    | T_PLUS { $$ = $<token_index>1; }
    | T_MINUS { $$ = $<token_index>1; }
    | T_BIT_NOT { $$ = $<token_index>1; }
    | T_NOT { $$ = $<token_index>1; }
    ;

    /* In every binary rule the left operand is made a value (mid-rule action)
    before the right operand is parsed: a left operand in jump form must be
    materialized before the right operand's code, or its jumps would skip it. */

    multiplicative_expr
    : unary_expr { $$ = $1; }
    | multiplicative_expr T_MUL { make_rvalue($1); } unary_expr {
    $$ = arith_binary("*", $1, $4, TOK_LINE($<token_index>2));
    }
    | multiplicative_expr T_DIV { make_rvalue($1); } unary_expr {
    $$ = arith_binary("/", $1, $4, TOK_LINE($<token_index>2));
    }
    | multiplicative_expr T_MOD { make_rvalue($1); } unary_expr {
    $$ = arith_binary("%", $1, $4, TOK_LINE($<token_index>2));
    }
    ;

    additive_expr
    : multiplicative_expr { $$ = $1; }
    | additive_expr T_PLUS { make_rvalue($1); } multiplicative_expr {
    $$ = arith_binary("+", $1, $4, TOK_LINE($<token_index>2));
    }
    | additive_expr T_MINUS { make_rvalue($1); } multiplicative_expr {
    $$ = arith_binary("-", $1, $4, TOK_LINE($<token_index>2));
    }
    ;

    shift_expr
    : additive_expr { $$ = $1; }
    | shift_expr T_LSHIFT { make_rvalue($1); } additive_expr {
    $$ = arith_binary("<<", $1, $4, TOK_LINE($<token_index>2));
    }
    | shift_expr T_RSHIFT { make_rvalue($1); } additive_expr {
    $$ = arith_binary(">>", $1, $4, TOK_LINE($<token_index>2));
    }
    ;

    relational_expr
    : shift_expr { $$ = $1; }
    | relational_expr T_LT { make_rvalue($1); } shift_expr {
    $$ = relational("<", $1, $4, TOK_LINE($<token_index>2));
    }
    | relational_expr T_GT { make_rvalue($1); } shift_expr {
    $$ = relational(">", $1, $4, TOK_LINE($<token_index>2));
    }
    | relational_expr T_LE { make_rvalue($1); } shift_expr {
    $$ = relational("<=", $1, $4, TOK_LINE($<token_index>2));
    }
    | relational_expr T_GE { make_rvalue($1); } shift_expr {
    $$ = relational(">=", $1, $4, TOK_LINE($<token_index>2));
    }
    ;

    equality_expr
    : relational_expr { $$ = $1; }
    | equality_expr T_EQ { make_rvalue($1); } relational_expr {
    $$ = relational("==", $1, $4, TOK_LINE($<token_index>2));
    }
    | equality_expr T_NE { make_rvalue($1); } relational_expr {
    $$ = relational("!=", $1, $4, TOK_LINE($<token_index>2));
    }
    ;

    and_expr
    : equality_expr { $$ = $1; }
    | and_expr T_BIT_AND { make_rvalue($1); } equality_expr {
    $$ = arith_binary("&", $1, $4, TOK_LINE($<token_index>2));
    }
    ;

    exclusive_or_expr
    : and_expr { $$ = $1; }
    | exclusive_or_expr T_BIT_XOR { make_rvalue($1); } and_expr {
    $$ = arith_binary("^", $1, $4, TOK_LINE($<token_index>2));
    }
    ;

    inclusive_or_expr
    : exclusive_or_expr { $$ = $1; }
    | inclusive_or_expr T_BIT_OR { make_rvalue($1); } exclusive_or_expr {
    $$ = arith_binary("|", $1, $4, TOK_LINE($<token_index>2));
    }
    ;

    logical_and_expr
    : inclusive_or_expr { $$ = $1; }
    | logical_and_expr T_AND { to_cond($1); $<ival>$ = nextquad(); } inclusive_or_expr {
    $$ = logical(true, $1, $<ival>3, $4, TOK_LINE($<token_index>2));
    }
    ;

    logical_or_expr
    : logical_and_expr { $$ = $1; }
    | logical_or_expr T_OR { to_cond($1); $<ival>$ = nextquad(); } logical_and_expr {
    $$ = logical(false, $1, $<ival>3, $4, TOK_LINE($<token_index>2));
    }
    ;

    conditional_expr
    : logical_or_expr { $$ = $1; }
    | logical_or_expr T_QUESTION { to_cond($1); $<ival>$ = nextquad(); }
    expr T_COLON { $<tern>$ = ternary_mid($4); }
    conditional_expr {
    $$ = ternary_end($1, $<ival>3, $<tern>6, $7, TOK_LINE($<token_index>2));
    }
    ;

    assignment_expr
    : conditional_expr { $$ = $1; }
    | unary_expr assignment_operator assignment_expr {
    $$ = assign_expr(TOK_TEXT($2), $1, $3, TOK_LINE($2));
    }
    ;

    assignment_operator
    : T_ASSIGN { $$ = $<token_index>1; }
    | T_PLUS_ASSIGN { $$ = $<token_index>1; }
    | T_MINUS_ASSIGN { $$ = $<token_index>1; }
    | T_MUL_ASSIGN { $$ = $<token_index>1; }
    | T_DIV_ASSIGN { $$ = $<token_index>1; }
    | T_MOD_ASSIGN { $$ = $<token_index>1; }
    | T_AND_ASSIGN { $$ = $<token_index>1; }
    | T_OR_ASSIGN { $$ = $<token_index>1; }
    | T_XOR_ASSIGN { $$ = $<token_index>1; }
    | T_LSHIFT_ASSIGN { $$ = $<token_index>1; }
    | T_RSHIFT_ASSIGN { $$ = $<token_index>1; }
    ;

    expr
    : assignment_expr { $$ = $1; }
    ;

%%

void yyerror(const char* msg) {
    std::ostringstream oss;
    oss << "Syntax Error at line " << yylineno << ": " << msg;
    g_syntax_errors.push_back(oss.str());
}

// foo/bar.c -> foo/bar.ir
static std::string default_output_path(const std::string& in) {
    size_t slash = in.find_last_of("/\\");
    size_t dot = in.find_last_of('.');
    if (dot != std::string::npos && (slash == std::string::npos || dot > slash))
        return in.substr(0, dot) + ".ir";
    return in + ".ir";
}

int main(int argc, char** argv) {
    const char* input_path = nullptr;
    std::string output_path;
    for (int i = 1; i < argc; i++) {
        std::string arg = argv[i];
        if (arg == "-o" && i + 1 < argc) output_path = argv[++i];
        else if (!input_path) input_path = argv[i];
        else input_path = nullptr, i = argc;
    }
    if (!input_path) {
        std::fprintf(stderr, "Usage: %s <source-file> [-o <output.ir>]\n", argv[0]);
        return 1;
    }

    FILE* input_file = std::fopen(input_path, "r");
    if (!input_file) {
        std::perror("Unable to open input file");
        return 1;
    }
    yyin = input_file;

    int parse_result = yyparse();
    std::fclose(input_file);

    if (g_had_lex_error) {
        std::cerr << "Lexical errors found; aborting.\n";
        for (const auto& msg : g_lex_errors)
            std::cerr << msg << "\n";
        return 1;
    }

    if (parse_result != 0 || !g_syntax_errors.empty()) {
        std::cerr << "Syntax errors found:\n";
        for (const auto& msg : g_syntax_errors)
            std::cerr << msg << "\n";
        return 1;
    }

    if (!g_sem_errors.empty()) {
        std::cerr << "Semantic errors found:\n";
        for (const auto& msg : g_sem_errors)
            std::cerr << msg << "\n";
        return 1;
    }

    if (output_path.empty()) output_path = default_output_path(input_path);
    FILE* out = std::fopen(output_path.c_str(), "w");
    if (!out) {
        std::perror("Unable to open output file");
        return 1;
    }
    std::string err;
    bool ok = write_ir(out, err);
    std::fclose(out);
    if (!ok) {
        std::remove(output_path.c_str());
        std::cerr << err << "\n";
        return 2;
    }
    std::cout << "IR written to " << output_path << "\n";
    return 0;
}
