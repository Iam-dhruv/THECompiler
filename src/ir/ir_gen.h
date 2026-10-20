#pragma once
#include <string>
#include <vector>
#include <unordered_map>
#include <unordered_set>
#include <cstdio>
#include "semantic_types.h"

// Three-address code store: quadruples, backpatch lists, temporaries, the
// data section, and the printer for the .ir file.

using List = std::vector<int>;   // quad indices of jumps awaiting a target

// One instruction. How each op is printed (x = res, a = a1, b = a2):
//   "="       x = a                 "cast"    x = (b) a
//   binary    x = a op b            "neg"/"~" x = -a / x = ~a
//   "addr"    x = &a                "deref"   x = *a
//   "*="      *x = a                "=[]"     x = a[b]     "[]="  x[a] = b
//   "goto"    goto T                "if"      if a goto T / if a x b goto T
//   "param"   param a               "call"    [x =] call a, b
//   "icall"   [x =] icall a, b      "return"  return [a]
//   "new"     x = new a             "delete"  delete a
// Indexed forms address bytes: a[b] is the object b bytes into variable a.
struct Quad {
    std::string op, a1, a2, res;
    int target = -1;   // jump target for goto / if (-1 = not yet patched)
};

inline std::vector<Quad> g_code;

inline int nextquad() { return (int)g_code.size(); }

inline int emit(const std::string& op, const std::string& a1 = "",
                const std::string& a2 = "", const std::string& res = "") {
    g_code.push_back({op, a1, a2, res, -1});
    return nextquad() - 1;
}

inline int emit_goto(int target = -1) {
    int q = emit("goto");
    g_code[q].target = target;
    return q;
}

// "if a1 goto _" when rel is empty, else "if a1 rel a2 goto _".
inline int emit_if(const std::string& a1, const std::string& rel = "", const std::string& a2 = "") {
    return emit("if", a1, a2, rel);
}

inline List makelist(int q) { return List{q}; }

inline List merge(const List& a, const List& b) {
    List r = a;
    r.insert(r.end(), b.begin(), b.end());
    return r;
}

inline void backpatch(const List& l, int target) {
    for (int q : l) g_code[q].target = target;
}

// ── Temporaries ─────────────────────────────────────────────────────────────
// Numbered per function: t1, t2, ... User names that look like temps are
// renamed when declared, so a name of this shape is always a temporary.

inline int g_temp_counter = 0;

inline std::string new_temp() { return "t" + std::to_string(++g_temp_counter); }

inline bool looks_like_temp(const std::string& s) {
    if (s.size() < 2 || s[0] != 't') return false;
    for (size_t i = 1; i < s.size(); i++)
        if (s[i] < '0' || s[i] > '9') return false;
    return true;
}

// ── Data section: globals, statics, string literals ─────────────────────────

struct DataEntry {
    std::string name, type;
    int size = 0;
    std::string init, comment;
};

inline std::vector<DataEntry> g_data;
inline std::unordered_set<std::string> g_data_names;

inline void add_data(const std::string& name, const std::string& type, int size,
                     const std::string& init, const std::string& comment) {
    g_data.push_back({name, type, size, init, comment});
    g_data_names.insert(name);
}

inline DataEntry* find_data(const std::string& name) {
    for (auto& d : g_data)
        if (d.name == name) return &d;
    return nullptr;
}

inline std::string escape_string(const std::string& raw) {
    std::string out;
    for (char c : raw) {
        switch (c) {
            case '\n': out += "\\n"; break;
            case '\t': out += "\\t"; break;
            case '\r': out += "\\r"; break;
            case '\\': out += "\\\\"; break;
            case '"':  out += "\\\""; break;
            case '\0': out += "\\0"; break;
            default:   out += c; break;
        }
    }
    return out;
}

inline std::unordered_map<std::string, std::string> g_string_labels;

// Returns the .strN label for a literal; identical literals share one entry.
// A .strN operand denotes the string's address.
inline std::string intern_string(const std::string& raw) {
    auto it = g_string_labels.find(raw);
    if (it != g_string_labels.end()) return it->second;
    std::string label = ".str" + std::to_string(g_string_labels.size());
    g_string_labels[raw] = label;
    int n = (int)raw.size() + 1;
    add_data(label, "char[" + std::to_string(n) + "]", n, "\"" + escape_string(raw) + "\"", "");
    return label;
}

// ── Functions ───────────────────────────────────────────────────────────────

struct FuncRecord {
    std::string name;                                       // mangled
    std::vector<std::pair<std::string, std::string>> params, locals;   // ir name, type
    int start = 0, end = 0;                                 // quad range [start, end)
};

inline std::vector<FuncRecord> g_funcs;

// ── Printer ─────────────────────────────────────────────────────────────────

inline std::string quad_to_string(const Quad& q) {
    const std::string T = std::to_string(q.target);
    const std::string& op = q.op;
    if (op == "=")      return q.res + " = " + q.a1;
    if (op == "cast")   return q.res + " = (" + q.a2 + ") " + q.a1;
    if (op == "neg")    return q.res + " = -" + q.a1;
    if (op == "~")      return q.res + " = ~" + q.a1;
    if (op == "addr")   return q.res + " = &" + q.a1;
    if (op == "deref")  return q.res + " = *" + q.a1;
    if (op == "*=")     return "*" + q.res + " = " + q.a1;
    if (op == "=[]")    return q.res + " = " + q.a1 + "[" + q.a2 + "]";
    if (op == "[]=")    return q.res + "[" + q.a1 + "] = " + q.a2;
    if (op == "goto")   return "goto " + T;
    if (op == "if")     return q.res.empty() ? "if " + q.a1 + " goto " + T
                                             : "if " + q.a1 + " " + q.res + " " + q.a2 + " goto " + T;
    if (op == "param")  return "param " + q.a1;
    if (op == "call" || op == "icall")
        return (q.res.empty() ? "" : q.res + " = ") + op + " " + q.a1 + ", " + q.a2;
    if (op == "return") return q.a1.empty() ? "return" : "return " + q.a1;
    if (op == "new")    return q.res + " = new " + q.a1;
    if (op == "delete") return "delete " + q.a1;
    return q.res + " = " + q.a1 + " " + op + " " + q.a2;   // binary operator
}

inline std::string join_pairs(const std::vector<std::pair<std::string, std::string>>& v) {
    std::string s;
    for (size_t i = 0; i < v.size(); i++) {
        if (i) s += ", ";
        s += v[i].first + ":" + v[i].second;
    }
    return s;
}

// Checks the code, then writes .types / .data / .text. Returns false (and
// writes nothing) if a jump was left without a target, which would mean a
// backpatching bug in the generator.
inline bool write_ir(FILE* out, std::string& err) {
    for (int i = 0; i < nextquad(); i++) {
        const Quad& q = g_code[i];
        if ((q.op == "goto" || q.op == "if") && (q.target < 0 || q.target > nextquad())) {
            err = "internal error: jump at quad " + std::to_string(i) + " has no valid target";
            return false;
        }
    }

    if (!g_layout_order.empty()) {
        std::fprintf(out, ".types\n");
        for (const auto& key : g_layout_order) {
            const CompositeLayout& l = g_layouts[key];
            std::string members;
            for (size_t i = 0; i < l.members.size(); i++) {
                if (i) members += ", ";
                members += l.members[i].name + ":" + type_to_string(l.members[i].type) +
                           " @" + std::to_string(l.members[i].offset);
            }
            std::fprintf(out, "  %s: size %d { %s }\n", key.c_str(), l.size, members.c_str());
        }
        std::fprintf(out, "\n");
    }

    std::fprintf(out, ".data\n");
    for (const auto& d : g_data) {
        std::fprintf(out, "  %s: %s (%d) = %s", d.name.c_str(), d.type.c_str(), d.size, d.init.c_str());
        if (!d.comment.empty()) std::fprintf(out, "  ; %s", d.comment.c_str());
        std::fprintf(out, "\n");
    }

    std::fprintf(out, "\n.text\n");
    for (size_t f = 0; f < g_funcs.size(); f++) {
        const FuncRecord& fr = g_funcs[f];
        if (f) std::fprintf(out, "\n");
        std::fprintf(out, "func_begin %s\n", fr.name.c_str());
        if (!fr.params.empty()) std::fprintf(out, "  params: %s\n", join_pairs(fr.params).c_str());
        if (!fr.locals.empty()) std::fprintf(out, "  locals: %s\n", join_pairs(fr.locals).c_str());
        for (int i = fr.start; i < fr.end; i++)
            std::fprintf(out, "  %d: %s\n", i, quad_to_string(g_code[i]).c_str());
        std::fprintf(out, "func_end %s\n", fr.name.c_str());
    }
    return true;
}
