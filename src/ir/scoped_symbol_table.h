#pragma once
#include <unordered_map>
#include <vector>
#include <string>
#include "semantic_types.h"
#include "common.h"

extern std::vector<TokenRecord> g_tokens;

struct SymbolInfo {
    const char* lexeme;    // interned pointer into StringPool
    TypeInfo type_info;
    int declared_line;
    int token_index;
};

// Scope stack for lexical scoping / name resolution. push_scope/pop_scope
// track nesting; lookup() walks innermost → outermost.
class ScopedSymbolTable {
    struct Scope {
        std::string label;
        std::unordered_map<std::string, SymbolInfo> symbols;
        int child_block_counter = 0;
    };
    std::vector<Scope> scope_stack;

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
        scope_stack.pop_back();
    }

    std::string current_scope_name() const {
        if (scope_stack.size() == 1) return "global";
        std::string result = scope_stack[1].label;
        for (size_t i = 2; i < scope_stack.size(); i++) { result += "."; result += scope_stack[i].label; }
        return result;
    }

    void insert(const char* lexeme, TypeInfo info, int line, int tok_idx) {
        scope_stack.back().symbols[lexeme] = SymbolInfo{lexeme, info, line, tok_idx};
    }

    void insert_global(const char* lexeme, TypeInfo info, int line, int tok_idx) {
        scope_stack.front().symbols[lexeme] = SymbolInfo{lexeme, info, line, tok_idx};
    }

    SymbolInfo* lookup(const std::string& lexeme) {
        for (auto it = scope_stack.rbegin(); it != scope_stack.rend(); ++it) {
            auto found = it->symbols.find(lexeme);
            if (found != it->symbols.end()) return &found->second;
        }
        return nullptr;
    }
};
