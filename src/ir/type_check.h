#pragma once
#include <string>
#include <vector>
#include <unordered_map>
#include <unordered_set>
#include <algorithm>
#include <deque>
#include <cstdarg>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include "semantic_types.h"
#include "ir_gen.h"
#include "scoped_symbol_table.h"

// Semantic analysis (type checking) plus the expression-level translation
// helpers the grammar actions call. Each helper checks its operands first and
// only emits code once they are well-typed; on an error it reports, returns an
// error-typed expression, and later helpers stay quiet about that operand.

enum LvalKind { LV_NONE, LV_NAME, LV_INDEX, LV_DEREF };

// Synthesized attribute of every expression non-terminal.
//   LV_NONE  : addr holds the value (temp, constant, or variable copy)
//   LV_NAME  : the variable named addr
//   LV_INDEX : the object `index` bytes into the variable named addr
//   LV_DEREF : the object addr points to
// Loads are deferred: an lvalue only becomes a value (rval) where one is
// needed, so assignment targets are never read. is_cond marks jump form,
// where truelist/falselist hold the exits instead of a value.
struct ExprAttr {
    TypeInfo type;
    LvalKind lv = LV_NONE;
    std::string addr, index;
    bool is_cond = false;
    List truelist, falselist;
    bool has_const = false;       // integer constant expression (cval)
    long cval = 0;
    bool is_float_lit = false;
    bool is_string = false;       // string literal; addr is its .strN once used
    std::string str_value;
    bool is_funcset = false;      // function name whose overload is not chosen yet
    std::string func_name;
    bool static_storage = false;  // names a global/static object
    int line = 0;
};

// ── Diagnostics ─────────────────────────────────────────────────────────────

inline std::vector<std::string> g_sem_errors;

inline void sem_error(int line, const char* fmt, ...) {
    char buf[1024];
    va_list args;
    va_start(args, fmt);
    std::vsnprintf(buf, sizeof(buf), fmt, args);
    va_end(args);
    g_sem_errors.push_back("Semantic Error at line " + std::to_string(line) + ": " + buf);
}

inline const char* ts(const TypeInfo& t) {
    // Pooled so several calls can appear in one sem_error argument list; a
    // deque never moves existing elements, so earlier pointers stay valid.
    static std::deque<std::string> pool;
    pool.push_back(type_to_string(t));
    return pool.back().c_str();
}

// ── Construction helpers ────────────────────────────────────────────────────

inline TypeInfo int_type() { return make_basic(BK_INT); }

inline ExprAttr* new_expr(int line) {
    auto* e = new ExprAttr;
    e->line = line;
    return e;
}

inline ExprAttr* error_expr(int line) {
    auto* e = new_expr(line);
    e->type.base_kind = BK_ERROR;
    e->addr = "?";
    return e;
}

inline bool bad(const ExprAttr* e) { return e->type.is_error(); }

inline ExprAttr* int_const_expr(long v, int line) {
    auto* e = new_expr(line);
    e->type = int_type();
    e->has_const = true;
    e->cval = v;
    e->addr = std::to_string(v);
    return e;
}

inline ExprAttr* temp_expr(const std::string& t, const TypeInfo& type, int line) {
    auto* e = new_expr(line);
    e->type = type;
    e->type.is_reference = false;
    e->addr = t;
    return e;
}

// ── Function-level context ──────────────────────────────────────────────────

struct JumpCtx {
    bool is_switch = false;
    List breaks, continues;
};

struct SwitchCtx {
    std::string value;                          // the switch operand, evaluated once
    int test_jump = -1;                         // "goto test" emitted before the bodies
    std::vector<std::pair<long, int>> cases;    // (case value, first quad of its body)
    int default_quad = -1;
};

struct FuncCtx {
    bool active = false;
    bool in_class = false;
    std::string ir_name;
    TypeInfo ret;
    std::unordered_map<std::string, int> labels;
    std::unordered_map<std::string, std::vector<std::pair<int, int>>> pending_gotos;  // label -> (quad, line)
    std::unordered_set<std::string> used_names;
    std::vector<JumpCtx> jumps;
    std::vector<SwitchCtx> switches;
};

inline FuncCtx g_fn;

// Set while a global/static initializer is parsed: &object of static storage
// then yields an address constant instead of emitting code.
inline bool g_const_init = false;

// ── IR names ────────────────────────────────────────────────────────────────

inline std::string first_free_name(const std::string& want,
                                   const std::unordered_set<std::string>& taken) {
    auto is_taken = [&](const std::string& n) {
        return taken.count(n) || g_data_names.count(n) || looks_like_temp(n);
    };
    if (!is_taken(want)) return want;
    for (int k = 1;; k++) {
        std::string n = want + "." + std::to_string(k);
        if (!is_taken(n)) return n;
    }
}

// Locals and parameters keep their source name unless it would clash with
// another local of the same function, a global, or a temporary.
inline std::string unique_local_name(const std::string& want) {
    std::string n = first_free_name(want, g_fn.used_names);
    g_fn.used_names.insert(n);
    return n;
}

inline std::string unique_global_name(const std::string& want) {
    return first_free_name(want, {});
}

// A static local lives in .data as <function>.<name>.
inline std::string unique_static_name(const std::string& want) {
    return first_free_name(g_fn.ir_name + "." + want, {});
}

// ── Constants and offsets ───────────────────────────────────────────────────

inline bool parse_int_literal(const std::string& s, long& v) {
    if (s.empty()) return false;
    size_t i = (s[0] == '-') ? 1 : 0;
    if (i == s.size()) return false;
    for (size_t k = i; k < s.size(); k++)
        if (s[k] < '0' || s[k] > '9') return false;
    v = std::strtol(s.c_str(), nullptr, 10);
    return true;
}

// Byte offset a + b, folded when both are literals.
inline std::string add_offsets(const std::string& a, const std::string& b) {
    long x, y;
    bool ca = parse_int_literal(a, x), cb = parse_int_literal(b, y);
    if (ca && cb) return std::to_string(x + y);
    if (ca && x == 0) return b;
    if (cb && y == 0) return a;
    std::string t = new_temp();
    emit("+", a, b, t);
    return t;
}

// value * size for a non-constant value.
inline std::string scale_value(const std::string& v, int size) {
    if (size == 1) return v;
    std::string t = new_temp();
    emit("*", v, std::to_string(size), t);
    return t;
}

// Offset of element `idx` for elements of `size` bytes.
inline std::string element_offset(const ExprAttr* idx, int size) {
    if (idx->has_const) return std::to_string(idx->cval * size);
    return scale_value(idx->addr, size);
}

// ── Built-in library functions ──────────────────────────────────────────────

inline bool is_builtin(const std::string& n) {
    return n == "printf" || n == "scanf" || n == "malloc" || n == "free";
}

inline TypeInfo builtin_return(const std::string& n) {
    if (n == "malloc") return make_basic(BK_VOID, 1);
    if (n == "free")   return make_basic(BK_VOID);
    return int_type();
}

// ── Value / address / store ─────────────────────────────────────────────────

inline void to_value(ExprAttr* e);

inline std::string addr_of_name(const std::string& name, bool static_storage) {
    if (g_const_init && static_storage) return "&" + name;
    std::string t = new_temp();
    emit("addr", name, "", t);
    return t;
}

// Address of an lvalue.
inline std::string address_of_object(ExprAttr* e) {
    switch (e->lv) {
        case LV_NAME:  return addr_of_name(e->addr, e->static_storage);
        case LV_INDEX: return add_offsets(addr_of_name(e->addr, e->static_storage), e->index);
        case LV_DEREF: return e->addr;
        default:       return "?";
    }
}

// The single overload of a function name used as a value (its address).
inline std::string resolve_funcset_single(ExprAttr* e) {
    auto it = g_functions.find(e->func_name);
    if (it == g_functions.end()) {
        sem_error(e->line, "cannot take the address of built-in function '%s'", e->func_name.c_str());
        e->type.base_kind = BK_ERROR;
        return "?";
    }
    if (it->second.size() != 1) {
        sem_error(e->line, "reference to overloaded function '%s' is ambiguous", e->func_name.c_str());
        e->type.base_kind = BK_ERROR;
        return "?";
    }
    e->type = it->second[0].type;
    e->type.func_ptr_depth = 1;
    return "&" + it->second[0].mangled;
}

// The value of e as an operand string, emitting a load if needed. Arrays
// and functions decay to their address.
inline std::string rval(ExprAttr* e) {
    if (bad(e)) return "?";
    if (e->is_cond) to_value(e);
    if (e->is_funcset) return resolve_funcset_single(e);
    if (e->is_string) {
        if (e->addr.empty()) e->addr = intern_string(e->str_value);
        return e->addr;
    }
    switch (e->lv) {
        case LV_NONE:
            return e->addr;
        case LV_NAME:
            if (e->type.is_array()) return address_of_object(e);
            return e->addr;
        case LV_INDEX: {
            if (e->type.is_array()) return address_of_object(e);
            std::string t = new_temp();
            emit("=[]", e->addr, e->index, t);
            return t;
        }
        case LV_DEREF: {
            if (e->type.is_array() || e->type.is_function()) return e->addr;
            std::string t = new_temp();
            emit("deref", e->addr, "", t);
            return t;
        }
    }
    return e->addr;
}

// Turns e into a plain value in place (LV_NONE).
inline void make_rvalue(ExprAttr* e) {
    if (bad(e)) return;
    if (e->is_cond) { to_value(e); return; }
    if (e->lv == LV_NONE && !e->is_funcset && !(e->is_string && e->addr.empty())) return;
    bool funcset = e->is_funcset;
    bool decays = e->type.is_array() || e->type.is_function();
    std::string v = rval(e);
    if (decays && !funcset) e->type = decay(e->type);
    e->addr = v;
    e->lv = LV_NONE;
    e->index.clear();
    e->is_funcset = false;
    e->static_storage = false;
}

inline void store(ExprAttr* lhs, const std::string& v) {
    switch (lhs->lv) {
        case LV_NAME:  emit("=", v, "", lhs->addr); break;
        case LV_INDEX: emit("[]=", lhs->index, v, lhs->addr); break;
        case LV_DEREF: emit("*=", v, "", lhs->addr); break;
        default: break;
    }
}

// ── Jump form ───────────────────────────────────────────────────────────────

// Value -> jump form: "if v goto _" (true) / "goto _" (false). A constant
// condition needs only the one jump that can be taken.
inline void to_cond(ExprAttr* e) {
    if (e->is_cond) return;
    if (bad(e)) { e->is_cond = true; return; }
    if (!e->is_funcset && !decay(e->type).is_scalar()) {
        sem_error(e->line, "used '%s' where a scalar value is required", ts(e->type));
        e->type.base_kind = BK_ERROR;
        e->is_cond = true;
        return;
    }
    if (e->has_const) {
        if (e->cval) e->truelist = makelist(emit_goto());
        else         e->falselist = makelist(emit_goto());
        e->is_cond = true;
        return;
    }
    std::string v = rval(e);
    e->truelist = makelist(emit_if(v));
    e->falselist = makelist(emit_goto());
    e->is_cond = true;
}

// Jump form -> value: t = 1 on the true exit, t = 0 on the false exit.
inline void to_value(ExprAttr* e) {
    if (!e->is_cond) return;
    std::string t = new_temp();
    backpatch(e->truelist, nextquad());
    emit("=", "1", "", t);
    emit_goto(nextquad() + 2);
    backpatch(e->falselist, nextquad());
    emit("=", "0", "", t);
    e->is_cond = false;
    e->truelist.clear();
    e->falselist.clear();
    e->lv = LV_NONE;
    e->addr = t;
    e->has_const = false;
    if (!bad(e)) e->type = int_type();
}

// ── Conversions ─────────────────────────────────────────────────────────────

// Integer <-> floating conversions and float <-> double are explicit casts
// in the IR; char/int/enum share one integer class and need none.
inline bool needs_cast(const TypeInfo& from, const TypeInfo& to) {
    if (!from.is_arith() || !to.is_arith()) return false;
    if (from.is_floating() != to.is_floating()) return true;
    return from.is_floating() && from.base_kind != to.base_kind;
}

// Converts value v (of e's type) to `to`. Literal conversions are folded.
inline std::string cast_value(const ExprAttr* e, const std::string& v, const TypeInfo& to) {
    if (!needs_cast(e->type, to)) return v;
    if (e->has_const && to.is_floating()) return std::to_string(e->cval) + ".0";
    if (e->is_float_lit) {
        if (to.is_floating()) return v;
        return std::to_string((long)std::strtod(v.c_str(), nullptr));
    }
    std::string t = new_temp();
    emit("cast", v, type_to_string(to), t);
    return t;
}

inline bool is_void_ptr(const TypeInfo& t) {
    return t.is_plain() && t.base_kind == BK_VOID && t.pointer_depth == 1;
}

// Checks that e may be stored into an object of type `to` (assignment,
// initialization, argument passing, return) and produces the converted value.
inline bool assign_value(ExprAttr* e, TypeInfo to, int line, const std::string& what, std::string& out) {
    to.is_reference = to.is_static = to.is_typedef = false;
    out = "?";
    if (bad(e) || to.is_error()) return false;
    if (e->is_cond) to_value(e);

    if (e->is_funcset) {
        auto it = g_functions.find(e->func_name);
        if (to.is_func_ptr() && it != g_functions.end()) {
            for (const auto& f : it->second) {
                TypeInfo fp = f.type;
                fp.func_ptr_depth = 1;
                if (same_type(fp, to)) { out = "&" + f.mangled; return true; }
            }
            sem_error(line, "no overload of '%s' matches '%s' in %s",
                      e->func_name.c_str(), ts(to), what.c_str());
            return false;
        }
        sem_error(line, "cannot convert function '%s' to '%s' in %s",
                  e->func_name.c_str(), ts(to), what.c_str());
        return false;
    }

    TypeInfo from = decay(e->type);
    bool ok = false;
    if (to.is_arith() && from.is_arith()) {
        ok = true;
    } else if (to.is_func_ptr()) {
        ok = (from.is_func_ptr() && same_type(from, to)) || (e->has_const && e->cval == 0);
    } else if (to.is_pointer()) {
        if (from.is_pointer() && !from.is_func_ptr())
            ok = same_type(from, to) || is_void_ptr(from) || is_void_ptr(to);
        else
            ok = e->has_const && e->cval == 0;
    } else if (to.is_composite()) {
        ok = same_type(from, to);
    }
    if (!ok) {
        if (from.is_func_ptr() && to.is_func_ptr())
            sem_error(line, "incompatible function pointer types in %s ('%s' to '%s')",
                      what.c_str(), ts(e->type), ts(to));
        else
            sem_error(line, "incompatible types in %s ('%s' to '%s')",
                      what.c_str(), ts(e->type), ts(to));
        return false;
    }
    out = cast_value(e, rval(e), to);
    return true;
}

// ── Operators ───────────────────────────────────────────────────────────────

inline TypeInfo arith_result(const TypeInfo& a, const TypeInfo& b) {
    if (a.base_kind == BK_DOUBLE || b.base_kind == BK_DOUBLE) return make_basic(BK_DOUBLE);
    if (a.base_kind == BK_FLOAT  || b.base_kind == BK_FLOAT)  return make_basic(BK_FLOAT);
    return int_type();
}

// 32-bit int arithmetic on two constants; false when it can't be folded.
inline bool fold_int(const std::string& op, long a, long b, long& r) {
    int64_t x = a, y = b, v;
    if      (op == "+")  v = x + y;
    else if (op == "-")  v = x - y;
    else if (op == "*")  v = x * y;
    else if (op == "/")  { if (y == 0) return false; v = x / y; }
    else if (op == "%")  { if (y == 0) return false; v = x % y; }
    else if (op == "<<") { if (y < 0 || y > 31) return false; v = x << y; }
    else if (op == ">>") { if (y < 0 || y > 31) return false; v = x >> y; }
    else if (op == "&")  v = x & y;
    else if (op == "|")  v = x | y;
    else if (op == "^")  v = x ^ y;
    else if (op == "<")  v = x < y;
    else if (op == ">")  v = x > y;
    else if (op == "<=") v = x <= y;
    else if (op == ">=") v = x >= y;
    else if (op == "==") v = x == y;
    else if (op == "!=") v = x != y;
    else return false;
    r = (long)(int32_t)(uint32_t)v;
    return true;
}

inline ExprAttr* pointer_arith(const std::string& op, ExprAttr* a, ExprAttr* b, int line) {
    auto elem_size = [](const TypeInfo& p) { return p.is_func_ptr() ? 0 : sizeof_type(pointee(p)); };
    const TypeInfo& ta = a->type;
    const TypeInfo& tb = b->type;

    if (ta.is_pointer() && tb.is_pointer()) {
        int sz = elem_size(ta);
        if (op != "-" || !same_type(ta, tb) || sz == 0) {
            sem_error(line, "invalid operands to binary '%s' ('%s' and '%s')", op.c_str(), ts(ta), ts(tb));
            return error_expr(line);
        }
        std::string t = new_temp();
        emit("-", a->addr, b->addr, t);
        if (sz == 1) return temp_expr(t, int_type(), line);
        std::string t2 = new_temp();
        emit("/", t, std::to_string(sz), t2);
        return temp_expr(t2, int_type(), line);
    }

    ExprAttr* p = ta.is_pointer() ? a : b;
    ExprAttr* n = ta.is_pointer() ? b : a;
    int sz = elem_size(p->type);
    if (!n->type.is_integral() || (op == "-" && p == b) || sz == 0) {
        sem_error(line, "invalid operands to binary '%s' ('%s' and '%s')", op.c_str(), ts(ta), ts(tb));
        return error_expr(line);
    }
    std::string off = element_offset(n, sz);
    std::string t = new_temp();
    if (p == a) emit(op, p->addr, off, t);
    else        emit(op, off, p->addr, t);
    return temp_expr(t, p->type, line);
}

// + - * / % << >> & | ^ . The left operand was made a value before the right
// operand was parsed, so its load precedes the right operand's code.
inline ExprAttr* arith_binary(const std::string& op, ExprAttr* a, ExprAttr* b, int line) {
    if (bad(a) || bad(b)) return error_expr(line);
    make_rvalue(a);
    make_rvalue(b);
    if (bad(a) || bad(b)) return error_expr(line);
    const TypeInfo& ta = a->type;
    const TypeInfo& tb = b->type;

    if ((op == "+" || op == "-") && (ta.is_pointer() || tb.is_pointer()))
        return pointer_arith(op, a, b, line);

    bool integer_only = op == "%" || op == "<<" || op == ">>" || op == "&" || op == "|" || op == "^";
    bool ok = integer_only ? (ta.is_integral() && tb.is_integral()) : (ta.is_arith() && tb.is_arith());
    if (!ok) {
        sem_error(line, "invalid operands to binary '%s' ('%s' and '%s')", op.c_str(), ts(ta), ts(tb));
        return error_expr(line);
    }

    long r;
    if (a->has_const && b->has_const && fold_int(op, a->cval, b->cval, r))
        return int_const_expr(r, line);

    TypeInfo rt = (op == "<<" || op == ">>") ? int_type() : arith_result(ta, tb);
    std::string va = cast_value(a, a->addr, rt);
    std::string vb = cast_value(b, b->addr, rt);
    std::string t = new_temp();
    emit(op, va, vb, t);
    return temp_expr(t, rt, line);
}

// < > <= >= == != : produce jump form.
inline ExprAttr* relational(const std::string& rel, ExprAttr* a, ExprAttr* b, int line) {
    if (bad(a) || bad(b)) { ExprAttr* e = error_expr(line); e->is_cond = true; return e; }
    make_rvalue(a);
    make_rvalue(b);
    if (bad(a) || bad(b)) { ExprAttr* e = error_expr(line); e->is_cond = true; return e; }
    const TypeInfo& ta = a->type;
    const TypeInfo& tb = b->type;
    std::string va = a->addr, vb = b->addr;

    if (ta.is_arith() && tb.is_arith()) {
        long r;
        if (a->has_const && b->has_const && fold_int(rel, a->cval, b->cval, r))
            return int_const_expr(r, line);
        TypeInfo ct = arith_result(ta, tb);
        va = cast_value(a, va, ct);
        vb = cast_value(b, vb, ct);
    } else if (ta.is_pointer() && tb.is_pointer()) {
        if (!same_type(ta, tb) && !is_void_ptr(ta) && !is_void_ptr(tb)) {
            sem_error(line, "comparison between distinct pointer types ('%s' and '%s')", ts(ta), ts(tb));
            ExprAttr* e = error_expr(line); e->is_cond = true; return e;
        }
    } else if (!((ta.is_pointer() && b->has_const && b->cval == 0) ||
                 (tb.is_pointer() && a->has_const && a->cval == 0))) {
        sem_error(line, "invalid operands to binary '%s' ('%s' and '%s')", rel.c_str(), ts(ta), ts(tb));
        ExprAttr* e = error_expr(line); e->is_cond = true; return e;
    }

    ExprAttr* e = new_expr(line);
    e->type = int_type();
    e->is_cond = true;
    e->truelist = makelist(emit_if(va, rel, vb));
    e->falselist = makelist(emit_goto());
    return e;
}

// B1 && M B2 / B1 || M B2 (B1 was put in jump form before M was recorded).
inline ExprAttr* logical(bool is_and, ExprAttr* a, int m, ExprAttr* b, int line) {
    to_cond(b);
    ExprAttr* e = new_expr(line);
    e->type = (bad(a) || bad(b)) ? make_basic(BK_ERROR) : int_type();
    e->is_cond = true;
    if (is_and) {
        backpatch(a->truelist, m);
        e->truelist = b->truelist;
        e->falselist = merge(a->falselist, b->falselist);
    } else {
        backpatch(a->falselist, m);
        e->truelist = merge(a->truelist, b->truelist);
        e->falselist = b->falselist;
    }
    return e;
}

inline ExprAttr* address_of_expr(ExprAttr* e, int line) {
    if (bad(e)) return error_expr(line);
    if (e->is_funcset) {
        std::string a = resolve_funcset_single(e);
        if (bad(e)) return error_expr(line);
        ExprAttr* r = temp_expr(a, e->type, line);
        return r;
    }
    if (e->is_cond || e->lv == LV_NONE) {
        sem_error(line, "lvalue required as unary '&' operand");
        return error_expr(line);
    }
    TypeInfo t = e->type;
    if (t.is_function()) {           // &*fp
        t.func_ptr_depth = 1;
        return temp_expr(e->addr, t, line);
    }
    t = t.is_array() ? decay(t) : pointer_to(t);
    return temp_expr(address_of_object(e), t, line);
}

inline ExprAttr* deref_expr(ExprAttr* e, int line) {
    if (bad(e)) return error_expr(line);
    if (e->is_funcset) return e;     // *f is f
    make_rvalue(e);
    if (bad(e)) return error_expr(line);
    ExprAttr* r = new_expr(line);
    r->lv = LV_DEREF;
    r->addr = e->addr;
    if (e->type.is_func_ptr()) {     // *fp designates the function
        r->type = e->type;
        r->type.func_ptr_depth = 0;
        return r;
    }
    if (!e->type.is_pointer()) {
        sem_error(line, "invalid type argument of unary '*' (have '%s')", ts(e->type));
        return error_expr(line);
    }
    r->type = pointee(e->type);
    if (r->type.is_void()) {
        sem_error(line, "dereferencing a 'void*' pointer");
        return error_expr(line);
    }
    return r;
}

inline ExprAttr* unary_op(const std::string& op, ExprAttr* e, int line) {
    if (op == "&") return address_of_expr(e, line);
    if (op == "*") return deref_expr(e, line);
    if (bad(e)) return error_expr(line);

    if (op == "!") {
        if (e->has_const) return int_const_expr(!e->cval, line);
        to_cond(e);
        ExprAttr* r = new_expr(line);
        r->type = bad(e) ? make_basic(BK_ERROR) : int_type();
        r->is_cond = true;
        r->truelist = e->falselist;
        r->falselist = e->truelist;
        return r;
    }

    make_rvalue(e);
    if (bad(e)) return error_expr(line);
    bool ok = (op == "~") ? e->type.is_integral() : e->type.is_arith();
    if (!ok) {
        sem_error(line, "wrong type argument to unary '%s' ('%s')", op.c_str(), ts(e->type));
        return error_expr(line);
    }
    if (op == "+") return e;
    if (e->has_const) return int_const_expr(op == "-" ? -e->cval : ~e->cval, line);
    if (op == "-" && e->is_float_lit) {
        ExprAttr* r = new ExprAttr(*e);
        r->addr = (r->addr[0] == '-') ? r->addr.substr(1) : "-" + r->addr;
        return r;
    }
    TypeInfo rt = e->type.is_floating() ? e->type : int_type();
    std::string t = new_temp();
    emit(op == "-" ? "neg" : "~", e->addr, "", t);
    return temp_expr(t, rt, line);
}

inline bool check_modifiable(ExprAttr* e, int line, const char* what) {
    if (bad(e)) return false;
    if (e->is_cond || e->lv == LV_NONE || e->is_funcset ||
        e->type.is_array() || e->type.is_function()) {
        sem_error(line, "lvalue required as %s", what);
        return false;
    }
    return true;
}

// ++x / --x / x++ / x--
inline ExprAttr* incdec(ExprAttr* e, bool inc, bool post, int line) {
    if (!check_modifiable(e, line, inc ? "increment operand" : "decrement operand"))
        return error_expr(line);
    if (!e->type.is_scalar() || e->type.is_func_ptr()) {
        sem_error(line, "wrong type argument to %s ('%s')", inc ? "increment" : "decrement", ts(e->type));
        return error_expr(line);
    }
    std::string step = "1";
    if (e->type.is_pointer()) {
        int sz = sizeof_type(pointee(e->type));
        if (sz == 0) {
            sem_error(line, "arithmetic on a pointer to an incomplete type ('%s')", ts(e->type));
            return error_expr(line);
        }
        step = std::to_string(sz);
    } else if (e->type.is_floating()) {
        step = "1.0";
    }
    std::string op = inc ? "+" : "-";

    if (e->lv == LV_NAME) {
        if (post) {
            std::string t = new_temp();
            emit("=", e->addr, "", t);
            emit(op, e->addr, step, e->addr);
            return temp_expr(t, e->type, line);
        }
        emit(op, e->addr, step, e->addr);
        return temp_expr(e->addr, e->type, line);
    }
    ExprAttr cur = *e;
    std::string old = rval(&cur);
    std::string t = new_temp();
    emit(op, old, step, t);
    store(e, t);
    return temp_expr(post ? old : t, e->type, line);
}

// = and the compound assignments (op is the operator lexeme).
inline ExprAttr* assign_expr(const std::string& op, ExprAttr* lhs, ExprAttr* rhs, int line) {
    if (bad(lhs) || bad(rhs)) return error_expr(line);
    if (!check_modifiable(lhs, line, "left operand of assignment")) return error_expr(line);
    std::string v;
    if (op == "=") {
        if (!assign_value(rhs, lhs->type, line, "assignment", v)) return error_expr(line);
    } else {
        ExprAttr* cur = new ExprAttr(*lhs);
        ExprAttr* res = arith_binary(op.substr(0, op.size() - 1), cur, rhs, line);
        if (bad(res) || !assign_value(res, lhs->type, line, "assignment", v)) return error_expr(line);
    }
    store(lhs, v);
    return temp_expr(v, lhs->type, line);
}

// s.f and p->f
inline ExprAttr* member_expr(ExprAttr* base, const std::string& name, bool arrow, int line) {
    if (bad(base)) return error_expr(line);
    ExprAttr obj = *base;
    if (arrow) {
        make_rvalue(&obj);
        if (bad(&obj)) return error_expr(line);
        if (!obj.type.is_pointer() || obj.type.is_func_ptr() || !pointee(obj.type).is_composite()) {
            sem_error(line, "invalid type argument of '->' (have '%s')", ts(obj.type));
            return error_expr(line);
        }
        obj.type = pointee(obj.type);
        obj.lv = LV_DEREF;
    } else {
        if (obj.is_cond || !obj.type.is_composite()) {
            sem_error(line, "request for member '%s' in something not a structure or union", name.c_str());
            return error_expr(line);
        }
        if (obj.lv == LV_NONE) obj.lv = LV_NAME;   // struct value held in a temp
    }
    const CompositeLayout* l = find_layout(obj.type);
    if (!l || !l->complete) {
        sem_error(line, "invalid use of incomplete type '%s'", ts(obj.type));
        return error_expr(line);
    }
    const MemberInfo* m = nullptr;
    for (const auto& mi : l->members)
        if (mi.name == name) { m = &mi; break; }
    if (!m) {
        sem_error(line, "'%s' has no member named '%s'", ts(obj.type), name.c_str());
        return error_expr(line);
    }

    ExprAttr* r = new_expr(line);
    r->type = m->type;
    r->static_storage = obj.static_storage;
    std::string off = std::to_string(m->offset);
    switch (obj.lv) {
        case LV_NAME:  r->lv = LV_INDEX; r->addr = obj.addr; r->index = off; break;
        case LV_INDEX: r->lv = LV_INDEX; r->addr = obj.addr; r->index = add_offsets(obj.index, off); break;
        default:       r->lv = LV_DEREF; r->addr = add_offsets(obj.addr, off); break;
    }
    return r;
}

// a[i]: an array stays an lvalue at a byte offset; a pointer is added to
// and dereferenced.
inline ExprAttr* index_expr(ExprAttr* base, ExprAttr* idx, int line) {
    if (bad(base) || bad(idx)) return error_expr(line);
    make_rvalue(idx);
    if (bad(idx)) return error_expr(line);
    if (!idx->type.is_integral()) {
        sem_error(line, "array subscript is not an integer ('%s')", ts(idx->type));
        return error_expr(line);
    }
    ExprAttr* r = new_expr(line);

    if (base->type.is_array() && base->lv != LV_NONE && !base->is_cond) {
        TypeInfo et = element_type(base->type);
        std::string off = element_offset(idx, sizeof_type(et));
        r->type = et;
        r->static_storage = base->static_storage;
        switch (base->lv) {
            case LV_NAME:  r->lv = LV_INDEX; r->addr = base->addr; r->index = off; break;
            case LV_INDEX: r->lv = LV_INDEX; r->addr = base->addr; r->index = add_offsets(base->index, off); break;
            default:       r->lv = LV_DEREF; r->addr = add_offsets(base->addr, off); break;
        }
        return r;
    }

    make_rvalue(base);
    if (bad(base)) return error_expr(line);
    if (!base->type.is_pointer() || base->type.is_func_ptr()) {
        sem_error(line, "subscripted value is neither array nor pointer ('%s')", ts(base->type));
        return error_expr(line);
    }
    TypeInfo et = pointee(base->type);
    int sz = sizeof_type(et);
    if (sz == 0) {
        sem_error(line, "subscript of a pointer to an incomplete type ('%s')", ts(base->type));
        return error_expr(line);
    }
    r->type = et;
    r->lv = LV_DEREF;
    r->addr = add_offsets(base->addr, element_offset(idx, sz));
    return r;
}

// ── Calls ───────────────────────────────────────────────────────────────────

// How well an argument fits a parameter: 0 exact, 1 via conversion, -1 not at all.
inline int arg_rank(ExprAttr* a, const TypeInfo& p) {
    if (bad(a)) return 0;
    if (p.is_reference) {
        TypeInfo pr = p;
        pr.is_reference = false;
        if (a->is_cond || a->lv == LV_NONE || a->is_funcset) return -1;
        return same_type(a->type, pr) ? 0 : -1;
    }
    if (a->is_funcset) {
        auto it = g_functions.find(a->func_name);
        if (!p.is_func_ptr() || it == g_functions.end()) return -1;
        for (const auto& f : it->second) {
            TypeInfo fp = f.type;
            fp.func_ptr_depth = 1;
            if (same_type(fp, p)) return 0;
        }
        return -1;
    }
    TypeInfo t = a->is_cond ? int_type() : decay(a->type);
    if (same_type(t, p)) return 0;
    if (t.is_arith() && p.is_arith()) return 1;
    if (p.is_pointer()) {
        if (!p.is_func_ptr() && t.is_pointer() && !t.is_func_ptr() && (is_void_ptr(t) || is_void_ptr(p))) return 1;
        if (a->has_const && a->cval == 0) return 1;
    }
    return -1;
}

// Picks the overload with the best worst-argument rank; ties are ambiguous.
inline const FuncSym* resolve_overload(const std::string& name, std::vector<ExprAttr*>& args, int line) {
    const auto& cands = g_functions[name];
    int best_rank = 99;
    std::vector<const FuncSym*> best;
    for (const auto& f : cands) {
        const auto& ps = f.type.func_info->param_types;
        if (ps.size() != args.size()) continue;
        int worst = 0;
        bool viable = true;
        for (size_t i = 0; i < ps.size() && viable; i++) {
            int r = arg_rank(args[i], ps[i]);
            if (r < 0) viable = false;
            else worst = std::max(worst, r);
        }
        if (!viable) continue;
        if (worst < best_rank) { best_rank = worst; best = {&f}; }
        else if (worst == best_rank) best.push_back(&f);
    }
    if (best.size() == 1) return best[0];
    if (best.size() > 1) {
        sem_error(line, "call of overloaded '%s' is ambiguous", name.c_str());
        return nullptr;
    }
    if (cands.size() == 1) {
        const auto& ps = cands[0].type.func_info->param_types;
        if (ps.size() != args.size()) {
            sem_error(line, "function '%s' expects %zu argument(s) but %zu were given",
                      name.c_str(), ps.size(), args.size());
            return nullptr;
        }
        for (size_t i = 0; i < ps.size(); i++) {
            if (arg_rank(args[i], ps[i]) >= 0) continue;
            if (ps[i].is_reference)
                sem_error(line, "argument %zu of '%s' must be an lvalue of type '%s' to bind to '%s'",
                          i + 1, name.c_str(), ts(decay(ps[i])), ts(ps[i]));
            else
                sem_error(line, "incompatible types in argument %zu of '%s' ('%s' to '%s')",
                          i + 1, name.c_str(), ts(args[i]->type), ts(ps[i]));
            return nullptr;
        }
    }
    sem_error(line, "no matching function for call to '%s'", name.c_str());
    return nullptr;
}

// Converts each argument for its parameter; reference parameters take the
// argument's address.
inline bool convert_args(std::vector<ExprAttr*>& args, const std::vector<TypeInfo>& ps,
                         const std::string& fname, int line, std::vector<std::string>& vals) {
    for (size_t i = 0; i < args.size(); i++) {
        if (ps[i].is_reference) {
            if (arg_rank(args[i], ps[i]) < 0) {
                sem_error(line, "argument %zu of '%s' must be an lvalue of type '%s' to bind to '%s'",
                          i + 1, fname.c_str(), ts(decay(ps[i])), ts(ps[i]));
                return false;
            }
            vals.push_back(address_of_object(args[i]));
        } else {
            std::string v;
            std::string what = "argument " + std::to_string(i + 1) + " of '" + fname + "'";
            if (!assign_value(args[i], ps[i], line, what, v)) return false;
            vals.push_back(v);
        }
    }
    return true;
}

inline ExprAttr* call_expr(ExprAttr* callee, std::vector<ExprAttr*>& args, int line) {
    if (bad(callee)) return error_expr(line);
    for (ExprAttr* a : args)
        if (bad(a)) return error_expr(line);

    std::vector<std::string> vals;
    TypeInfo ret;
    std::string target;
    bool indirect = false;

    if (callee->is_funcset && !g_functions.count(callee->func_name)) {
        // printf / scanf / malloc / free: no prototype, arguments pass as-is
        for (ExprAttr* a : args) {
            make_rvalue(a);
            if (bad(a)) return error_expr(line);
            if (a->type.is_void()) {
                sem_error(line, "void value passed to '%s'", callee->func_name.c_str());
                return error_expr(line);
            }
            vals.push_back(a->addr);
        }
        ret = builtin_return(callee->func_name);
        target = callee->func_name;
    } else if (callee->is_funcset) {
        const FuncSym* f = resolve_overload(callee->func_name, args, line);
        if (!f) return error_expr(line);
        std::vector<TypeInfo> ps = f->type.func_info->param_types;
        ret = f->type.return_type();
        target = f->mangled;
        if (!convert_args(args, ps, callee->func_name, line, vals)) return error_expr(line);
    } else {
        // fp(...) or (*fp)(...)
        const TypeInfo ft = callee->type;
        if (!(ft.is_func_ptr() || (ft.is_function() && callee->lv == LV_DEREF))) {
            sem_error(line, "called object is not a function or function pointer ('%s')", ts(ft));
            return error_expr(line);
        }
        std::string fv = rval(callee);
        const auto& ps = ft.func_info->param_types;
        if (ps.size() != args.size()) {
            sem_error(line, "function pointer of type '%s' expects %zu argument(s) but %zu were given",
                      ts(ft), ps.size(), args.size());
            return error_expr(line);
        }
        if (!convert_args(args, ps, fv, line, vals)) return error_expr(line);
        ret = ft.return_type();
        target = fv;
        indirect = true;
    }

    for (const auto& v : vals) emit("param", v);
    std::string op = indirect ? "icall" : "call";
    std::string n = std::to_string(vals.size());
    if (ret.is_void()) {
        emit(op, target, n, "");
        return temp_expr("", ret, line);
    }
    std::string t = new_temp();
    emit(op, target, n, t);
    ExprAttr* r = temp_expr(t, ret, line);
    if (ret.is_reference) r->lv = LV_DEREF;   // t holds the address of the referenced object
    return r;
}

// ── new / delete / return ───────────────────────────────────────────────────

inline ExprAttr* new_object(const TypeInfo& type, ExprAttr* count, int line) {
    TypeInfo t = type;
    t.is_static = t.is_typedef = false;
    int sz = sizeof_type(t);
    if (sz == 0) {
        sem_error(line, "invalid use of incomplete type '%s' in new", ts(t));
        return error_expr(line);
    }
    std::string amount = std::to_string(sz);
    if (count) {
        if (bad(count)) return error_expr(line);
        make_rvalue(count);
        if (!count->type.is_integral()) {
            sem_error(line, "size in array new must have integral type ('%s')", ts(count->type));
            return error_expr(line);
        }
        amount = element_offset(count, sz);
    }
    std::string r = new_temp();
    emit("new", amount, "", r);
    t = t.is_array() ? decay(t) : pointer_to(t);
    return temp_expr(r, t, line);
}

inline ExprAttr* delete_object(ExprAttr* e, int line) {
    if (bad(e)) return error_expr(line);
    make_rvalue(e);
    if (!e->type.is_pointer() || e->type.is_func_ptr()) {
        sem_error(line, "type '%s' argument given to delete, expected pointer", ts(e->type));
        return error_expr(line);
    }
    emit("delete", e->addr);
    return temp_expr("", make_basic(BK_VOID), line);
}

inline void return_stmt(ExprAttr* e, int line) {
    if (!e) {
        if (!g_fn.ret.is_void())
            sem_error(line, "return with no value in function returning '%s'", ts(g_fn.ret));
        emit("return");
        return;
    }
    if (bad(e)) return;
    if (g_fn.ret.is_void()) {
        sem_error(line, "return with a value in function returning 'void'");
        return;
    }
    if (g_fn.ret.is_reference) {   // return the address of the object being bound
        TypeInfo rt = g_fn.ret;
        rt.is_reference = false;
        if (e->is_cond || e->lv == LV_NONE || e->is_funcset || !same_type(e->type, rt)) {
            sem_error(line, "cannot bind return value of type '%s' to '%s': an lvalue of type '%s' is required",
                      ts(e->type), ts(g_fn.ret), ts(rt));
            return;
        }
        if ((e->lv == LV_NAME || e->lv == LV_INDEX) && !e->static_storage) {
            sem_error(line, "returning a reference to a local variable");
            return;
        }
        emit("return", address_of_object(e));
        return;
    }
    std::string v;
    if (assign_value(e, g_fn.ret, line, "return", v)) emit("return", v);
}
