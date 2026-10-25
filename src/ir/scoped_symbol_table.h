#pragma once
#include <unordered_map>
#include <vector>
#include <string>
#include "semantic_types.h"

enum SymKind { SK_VAR, SK_FUNC, SK_ENUM_CONST, SK_TYPEDEF };

struct SymbolInfo {
    const char* lexeme = nullptr;  // interned pointer into StringPool
    SymKind kind = SK_VAR;
    TypeInfo type_info;
    int declared_line = 0;
    std::string ir_name;           // the name the IR uses (renamed if shadowing)
    long enum_value = 0;           // SK_ENUM_CONST
    bool static_storage = false;   // global or static: lives in .data
};

// One entry per overload of a function name. Function names are entered in
// the global scope as a single SK_FUNC symbol; the overloads live here.
struct FuncSym {
    TypeInfo type;            // is_function() == true
    std::string mangled;
    bool defined = false;
    int line = 0;
};

inline std::unordered_map<std::string, std::vector<FuncSym>> g_functions;

// Scope stack for lexical scoping / name resolution. push_scope/pop_scope
// track nesting; lookup() walks innermost → outermost.
class ScopedSymbolTable {
    struct Scope {
        std::string label;
        std::unordered_map<std::string, SymbolInfo> symbols;
        int child_block_counter = 0;
    };
    std::vector<Scope> scope_stack;

    static SymbolInfo* insert_into(Scope& scope, const char* lexeme, SymbolInfo info) {
        if (scope.symbols.count(lexeme)) return nullptr;
        info.lexeme = lexeme;
        return &(scope.symbols[lexeme] = std::move(info));
    }

    static SymbolInfo* find_in(Scope& scope, const std::string& lexeme) {
        auto found = scope.symbols.find(lexeme);
        return found == scope.symbols.end() ? nullptr : &found->second;
    }

public:
    ScopedSymbolTable() { scope_stack.push_back({"global", {}, 0}); }

    void push_scope(const std::string& label) {
        scope_stack.push_back({label, {}, 0});
    }

    std::string push_block_scope() {
        scope_stack.back().child_block_counter++;
        push_scope("block" + std::to_string(scope_stack.back().child_block_counter));
        return current_scope_name();
    }

    void pop_scope() {
        if (scope_stack.size() > 1) scope_stack.pop_back();
    }

    std::string current_scope_name() const {
        if (scope_stack.size() == 1) return "global";
        std::string result = scope_stack[1].label;
        for (size_t i = 2; i < scope_stack.size(); i++) { result += "."; result += scope_stack[i].label; }
        return result;
    }

    // Insert into the innermost scope; nullptr if the name is already declared there.
    SymbolInfo* insert(const char* lexeme, SymbolInfo info) {
        return insert_into(scope_stack.back(), lexeme, std::move(info));
    }

    SymbolInfo* insert_global(const char* lexeme, SymbolInfo info) {
        return insert_into(scope_stack.front(), lexeme, std::move(info));
    }           

    SymbolInfo* lookup(const std::string& lexeme) {
        for (auto it = scope_stack.rbegin(); it != scope_stack.rend(); ++it)
            if (SymbolInfo* s = find_in(*it, lexeme)) return s;
        return nullptr;
    }

    SymbolInfo* lookup_current(const std::string& lexeme) {
        return find_in(scope_stack.back(), lexeme);
    }

    SymbolInfo* lookup_global(const std::string& lexeme) {
        return find_in(scope_stack.front(), lexeme);
    }
};
