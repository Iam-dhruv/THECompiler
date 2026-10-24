#pragma once
#include <string>
#include <vector>
#include <optional>
#include <memory>
#include <unordered_map>

// Type vocabulary shared by the symbol table, the type checker and the IR
// generator. Every function here is inline: this header is reached from both
// the parser and the lexer translation units.

enum BaseKind { BK_INT, BK_CHAR, BK_FLOAT, BK_DOUBLE, BK_VOID,
                BK_STRUCT, BK_UNION, BK_ENUM, BK_CLASS, BK_ERROR };

struct TypeInfo;

// Signature of a function, or of the function a function pointer targets.
// return_type is a shared_ptr to break the TypeInfo <-> FunctionTypeInfo cycle.
struct FunctionTypeInfo {
    std::shared_ptr<TypeInfo> return_type;
    std::vector<TypeInfo> param_types;
};

// Array extents, outermost first. -1 marks an extent that was not written
// ("int a[] = {...}") and is filled in from the initializer.
struct ArrayTypeInfo {
    std::vector<int> dims;
};

// Present for BK_STRUCT / BK_UNION / BK_ENUM / BK_CLASS.
struct CompositeTypeInfo {
    std::string tag;
};

// A type reads inside-out: base_kind, then pointer_depth levels of pointer,
// then (if present) array dimensions around that, then outer_pointer levels
// of pointer to the whole array. So `int *a[3]` is an array of 3 `int*`, and
// `int (*p)[3]` — what `int m[][3]` decays to — is a pointer to int[3].
// Functions and function pointers carry func_info; func_ptr_depth counts the
// pointer levels on the function: 0 a function, 1 int(*)(int), 2 int(**)(int).
// With array_info too it is an array of those: int (*ops[4])(int).
struct TypeInfo {
    BaseKind base_kind     = BK_INT;
    int      pointer_depth = 0;
    int      outer_pointer = 0;       // pointers to the array: int (*p)[3]
    bool     is_typedef    = false;
    bool     is_const      = false;
    bool     is_static     = false;
    bool     is_reference  = false;   // T& — stored as a pointer in the IR
    int      func_ptr_depth = 0;      // with func_info: pointers to that function

    std::optional<FunctionTypeInfo>  func_info;
    std::optional<ArrayTypeInfo>     array_info;
    std::optional<CompositeTypeInfo> composite_info;

    bool is_array()    const { return array_info.has_value() && outer_pointer == 0; }
    bool is_function() const { return func_info.has_value() && func_ptr_depth == 0; }
    // A function pointer that can be called; deeper levels are data pointers.
    bool is_func_ptr() const {
        return func_info.has_value() && func_ptr_depth == 1 && !array_info.has_value();
    }
    bool is_error()    const { return base_kind == BK_ERROR; }

    // Not an array, pointer to array, function or function pointer.
    bool is_plain()    const { return !array_info.has_value() && !func_info.has_value(); }
    bool is_void()     const { return is_plain() && pointer_depth == 0 && base_kind == BK_VOID; }
    bool is_pointer()  const {
        return (func_ptr_depth > 0 && !array_info) || outer_pointer > 0 || (is_plain() && pointer_depth > 0);
    }

    bool is_integral() const {
        return is_plain() && pointer_depth == 0 &&
               (base_kind == BK_CHAR || base_kind == BK_INT || base_kind == BK_ENUM);
    }
    bool is_floating() const {
        return is_plain() && pointer_depth == 0 &&
               (base_kind == BK_FLOAT || base_kind == BK_DOUBLE);
    }
    bool is_arith()  const { return is_integral() || is_floating(); }
    bool is_scalar() const { return is_arith() || is_pointer(); }
    bool is_composite() const {
        return is_plain() && pointer_depth == 0 &&
               (base_kind == BK_STRUCT || base_kind == BK_UNION || base_kind == BK_CLASS);
    }

    const TypeInfo& return_type() const { return *func_info->return_type; }
    std::string tag() const { return composite_info ? composite_info->tag : ""; }

    void make_array(std::vector<int> dims) { array_info = ArrayTypeInfo{std::move(dims)}; }
    void make_function(const TypeInfo& ret, std::vector<TypeInfo> params = {}) {
        func_info = FunctionTypeInfo{std::make_shared<TypeInfo>(ret), std::move(params)};
        base_kind = ret.base_kind;
    }
    void set_composite_tag(const std::string& tag) { composite_info = CompositeTypeInfo{tag}; }
};

inline TypeInfo make_basic(BaseKind k, int pointer_depth = 0) {
    TypeInfo t;
    t.base_kind = k;
    t.pointer_depth = pointer_depth;
    return t;
}

// ── Struct / union / class layouts ──────────────────────────────────────────

struct MemberInfo {
    std::string name;
    TypeInfo type;
    int offset = 0;
};

struct CompositeLayout {
    BaseKind kind = BK_STRUCT;
    std::string tag;
    std::vector<MemberInfo> members;
    int size = 0;
    int align = 1;
    bool complete = false;
};

// Keyed by "struct Point" / "union Value". Tags live in one global namespace.
inline std::unordered_map<std::string, CompositeLayout> g_layouts;
inline std::vector<std::string> g_layout_order;   // completion order, for printing

inline std::string kind_keyword(BaseKind k) {
    switch (k) {
        case BK_STRUCT: return "struct";
        case BK_UNION:  return "union";
        case BK_ENUM:   return "enum";
        case BK_CLASS:  return "class";
        default:        return "";
    }
}

inline std::string layout_key(BaseKind k, const std::string& tag) {
    return kind_keyword(k) + " " + tag;
}

inline const CompositeLayout* find_layout(const TypeInfo& t) {
    auto it = g_layouts.find(layout_key(t.base_kind, t.tag()));
    return it == g_layouts.end() ? nullptr : &it->second;
}

// ── Derived types ───────────────────────────────────────────────────────────

// Type of a[i] for an array a.
inline TypeInfo element_type(const TypeInfo& t) {
    TypeInfo e = t;
    e.array_info->dims.erase(e.array_info->dims.begin());
    if (e.array_info->dims.empty()) e.array_info.reset();
    return e;
}

// Type of *p for a pointer p.
inline TypeInfo pointee(const TypeInfo& t) {
    TypeInfo e = t;
    if (e.outer_pointer > 0) e.outer_pointer--;
    else if (e.func_info) e.func_ptr_depth--;
    else e.pointer_depth--;
    return e;
}

// Type of &x for an x of type t (not an array: arrays decay instead).
inline TypeInfo pointer_to(const TypeInfo& t) {
    TypeInfo p = t;
    p.is_reference = false;
    if (p.array_info) p.outer_pointer++;
    else if (p.func_info) p.func_ptr_depth++;
    else p.pointer_depth++;
    return p;
}

// Array-to-pointer and function-to-pointer decay. int[3] becomes int*;
// int[2][3] becomes a pointer to its first row, int(*)[3].
inline TypeInfo decay(const TypeInfo& t) {
    TypeInfo d = t;
    d.is_reference = false;
    if (d.is_array()) {
        if (d.array_info->dims.size() > 1) {
            d.array_info->dims.erase(d.array_info->dims.begin());
            d.outer_pointer = 1;
        } else {
            d.array_info.reset();
            if (d.func_info) d.func_ptr_depth++;   // int (*ops[4])(int) -> int(**)(int)
            else d.pointer_depth++;
        }
    } else if (d.is_function()) {
        d.func_ptr_depth = 1;
    }
    return d;
}

// ── Size and alignment (bytes) ──────────────────────────────────────────────

inline int sizeof_type(const TypeInfo& t) {
    if (t.is_reference || t.outer_pointer > 0) return 8;
    if (t.is_function()) return 0;
    int size;
    if (t.pointer_depth > 0 || t.func_ptr_depth > 0) {
        size = 8;
    } else {
        switch (t.base_kind) {
            case BK_CHAR:   size = 1; break;
            case BK_INT:
            case BK_FLOAT:
            case BK_ENUM:   size = 4; break;
            case BK_DOUBLE: size = 8; break;
            case BK_STRUCT:
            case BK_UNION:
            case BK_CLASS: {
                const CompositeLayout* l = find_layout(t);
                size = (l && l->complete) ? l->size : 0;
                break;
            }
            default:        size = 0; break;
        }
    }
    if (t.is_array())
        for (int d : t.array_info->dims) size *= (d < 0 ? 0 : d);
    return size;
}

inline int alignof_type(const TypeInfo& t) {
    if (t.is_reference || t.func_ptr_depth > 0 || t.outer_pointer > 0 || t.pointer_depth > 0) return 8;
    switch (t.base_kind) {
        case BK_CHAR:   return 1;
        case BK_INT:
        case BK_FLOAT:
        case BK_ENUM:   return 4;
        case BK_DOUBLE: return 8;
        case BK_STRUCT:
        case BK_UNION:
        case BK_CLASS: {
            const CompositeLayout* l = find_layout(t);
            return (l && l->complete) ? l->align : 1;
        }
        default:        return 1;
    }
}

// ── Comparison ──────────────────────────────────────────────────────────────

// Structural equality. Ignores qualifiers (static, typedef, const) and
// whether the outer type is a reference; parameter reference-ness is part of
// a function signature and is compared.
inline bool same_type(const TypeInfo& a, const TypeInfo& b) {
    if (a.is_error() || b.is_error()) return true;
    if (a.func_info.has_value() != b.func_info.has_value()) return false;
    if (a.func_ptr_depth != b.func_ptr_depth) return false;
    if (a.outer_pointer != b.outer_pointer) return false;
    if (a.array_info.has_value() != b.array_info.has_value()) return false;
    if (a.array_info && a.array_info->dims != b.array_info->dims) return false;
    if (a.func_info) {
        if (!same_type(a.return_type(), b.return_type()) ||
            a.return_type().is_reference != b.return_type().is_reference) return false;
        const auto& pa = a.func_info->param_types;
        const auto& pb = b.func_info->param_types;
        if (pa.size() != pb.size()) return false;
        for (size_t i = 0; i < pa.size(); i++)
            if (!same_type(pa[i], pb[i]) || pa[i].is_reference != pb[i].is_reference) return false;
        return true;
    }
    if (a.base_kind != b.base_kind || a.pointer_depth != b.pointer_depth) return false;
    return a.tag() == b.tag();
}

// ── Printing and name mangling ──────────────────────────────────────────────

inline std::string base_type_name(const TypeInfo& t) {
    switch (t.base_kind) {
        case BK_INT:    return "int";
        case BK_CHAR:   return "char";
        case BK_FLOAT:  return "float";
        case BK_DOUBLE: return "double";
        case BK_VOID:   return "void";
        case BK_STRUCT:
        case BK_UNION:
        case BK_ENUM:
        case BK_CLASS:  return kind_keyword(t.base_kind) + " " + t.tag();
        default:        return "<error>";
    }
}

inline std::string dims_to_string(const ArrayTypeInfo& a) {
    std::string s;
    for (int d : a.dims) s += "[" + (d < 0 ? std::string() : std::to_string(d)) + "]";
    return s;
}

// C-like spelling: int, char**, int&, int[2][3], int(*)[3], int(*)(int,int),
// int(**)(int,int), int(*[4])(int,int), int(*&)(int), int&(*)(int).
inline std::string type_to_string(const TypeInfo& t) {
    if (t.func_info) {
        std::string s = type_to_string(t.return_type());
        std::string inner = std::string(t.func_ptr_depth, '*') + (t.is_reference ? "&" : "");
        if (t.array_info) {
            if (t.outer_pointer > 0) inner += "(" + std::string(t.outer_pointer, '*') + ")";
            inner += dims_to_string(*t.array_info);
        }
        if (!inner.empty()) s += "(" + inner + ")";
        s += "(";
        const auto& ps = t.func_info->param_types;
        for (size_t i = 0; i < ps.size(); i++) {
            if (i) s += ",";
            s += type_to_string(ps[i]);
        }
        return s + ")";
    }
    std::string s = base_type_name(t) + std::string(t.pointer_depth, '*');
    if (t.outer_pointer > 0) s += "(" + std::string(t.outer_pointer, '*') + ")";
    if (t.is_reference) s += "&";
    if (t.array_info) s += dims_to_string(*t.array_info);
    return s;
}

// Parameter code used in mangled names: i c f d v for the basic types,
// S/U/C/e + length + tag for struct/union/class/enum, one P per pointer (or
// array) level, PA<n>_ for a pointer to an array of n, a leading R for a
// reference, PF<ret><params>E for a function pointer (PPF... one P per level).
inline std::string mangle_code(const TypeInfo& t) {
    std::string s = t.is_reference ? "R" : "";
    int depth = t.func_info ? t.func_ptr_depth : t.pointer_depth;
    if (t.outer_pointer > 0) {
        s += std::string(t.outer_pointer, 'P');
        for (int d : t.array_info->dims) s += "A" + std::to_string(d) + "_";
    } else if (t.is_array()) {
        depth += (int)t.array_info->dims.size();
    }
    if (t.func_info) {
        s += std::string(depth, 'P') + "F";
        s += mangle_code(t.return_type());
        for (const auto& p : t.func_info->param_types) s += mangle_code(p);
        return s + "E";
    }
    s += std::string(depth, 'P');
    std::string tag = t.tag();
    switch (t.base_kind) {
        case BK_INT:    s += "i"; break;
        case BK_CHAR:   s += "c"; break;
        case BK_FLOAT:  s += "f"; break;
        case BK_DOUBLE: s += "d"; break;
        case BK_VOID:   s += "v"; break;
        case BK_STRUCT: s += "S" + std::to_string(tag.size()) + tag; break;
        case BK_UNION:  s += "U" + std::to_string(tag.size()) + tag; break;
        case BK_CLASS:  s += "C" + std::to_string(tag.size()) + tag; break;
        case BK_ENUM:   s += "e" + std::to_string(tag.size()) + tag; break;
        default:        s += "?"; break;
    }
    return s;
}

// name@<param codes>, e.g. add@ii, add@ff, show@iPPc, f@v. `main` keeps its
// name so the entry point stays recognizable.
inline std::string mangle_function(const std::string& name, const TypeInfo& fn) {
    if (name == "main") return name;
    std::string codes;
    for (const auto& p : fn.func_info->param_types) codes += mangle_code(p);
    return name + "@" + (codes.empty() ? "v" : codes);
}
