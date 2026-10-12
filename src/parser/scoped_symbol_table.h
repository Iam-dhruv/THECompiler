#pragma once
#include <unordered_map>
#include <vector>
#include <string>
#include "semantic_types.h"
#include "common.h"

// Separate from symbol_table.h to avoid TokenType enum collision with Bison's
// generated token codes — both define T_IDENTIFIER, T_GT, etc.

extern std::vector<TokenRecord> g_tokens;

struct SymbolInfo {
    std::string lexeme;
    TypeInfo type_info;
    int declared_line;
    int token_index;
};

// Scope back-fill: instead of tagging tokens individually during parsing
// (fragile with Bison lookahead), pop_scope() bulk-fills all untagged tokens
// in the range the scope owned.
class ScopedSymbolTable {
    struct Scope {
        std::string label;
        std::unordered_map<std::string, SymbolInfo> symbols;
        int child_block_counter = 0;
        int token_range_start = 0;
    };
    std::vector<Scope> scope_stack;

public:
    ScopedSymbolTable() { scope_stack.push_back({"global", {}, 0, 0}); }

    void push_scope(const std::string& label) {
        scope_stack.push_back({label, {}, 0, (int)g_tokens.size()});
    }

    std::string push_block_scope() {
        scope_stack.back().child_block_counter++;
        push_scope("block" + std::to_string(scope_stack.back().child_block_counter));
        return current_scope_name();
    }

    void pop_scope() {
        std::string name = current_scope_name();
        int start = scope_stack.back().token_range_start;
        for (int i = start; i < (int)g_tokens.size(); i++)
            if (g_tokens[i].scope.empty()) g_tokens[i].scope = name;
        scope_stack.pop_back();
    }

    void finalize() {
        for (auto& t : g_tokens) if (t.scope.empty()) t.scope = "global";
    }

    std::string current_scope_name() const {
        if (scope_stack.size() == 1) return "global";
        std::string result = scope_stack[1].label;
        for (size_t i = 2; i < scope_stack.size(); i++) { result += "."; result += scope_stack[i].label; }
        return result;
    }

    void insert(const std::string& lexeme, TypeInfo info, int line, int tok_idx) {
        scope_stack.back().symbols[lexeme] = SymbolInfo{lexeme, info, line, tok_idx};
    }

    void insert_global(const std::string& lexeme, TypeInfo info, int line, int tok_idx) {
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
