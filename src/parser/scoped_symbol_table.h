#pragma once
#include <unordered_map>
#include <vector>
#include <string>
#include "semantic_types.h"
#include "common.h"

/* ============================================================================
 * scoped_symbol_table.h — the parser's (Assignment 2) scoped symbol table.
 *
 * Deliberately separate from symbol_table.h: symbol_table.h unconditionally
 * includes tokens.h, whose TokenType enum shares member names with Bison's
 * generated token codes (T_IDENTIFIER, T_GT, ...) in parser.tab.h — the two
 * collide if ever included in the same translation unit. lexer.l (Assignment
 * 1) needs symbol_table.h's SymbolEntry/SymbolTable + tokens.h; parser.y
 * (Assignment 2) needs ScopedSymbolTable + parser.tab.h's token codes. This
 * header gives parser.y the latter without dragging in the former.
 * ==========================================================================*/

extern std::vector<TokenRecord> g_tokens;

struct SymbolInfo {
    std::string lexeme;
    TypeInfo type_info;
    int declared_line;
    int token_index;        // index into g_tokens this symbol's declaration token came from
};

// Scope stack for the syntax analyzer's semantic classification pass. Scope is
// not back-patched onto individual tokens as they're parsed; instead each
// pop_scope() bulk-fills every still-empty g_tokens[i].scope in the range the
// scope owned. See "Scope stack + token-range back-fill" in implementation_plan.md
// for why (short version: back-patching individual tokens misses every token no
// grammar action ever touches, and is fragile against Bison's lookahead).
class ScopedSymbolTable {
    struct Scope {
        std::string label;                            // this level's own label only
        std::unordered_map<std::string, SymbolInfo> symbols;
        int child_block_counter = 0;                   // for naming nested "block1", "block2", ...
        int token_range_start = 0;                      // g_tokens.size() when this scope was pushed
    };
    std::vector<Scope> scope_stack;

public:
    ScopedSymbolTable() { scope_stack.push_back({"global", {}, 0, 0}); }

    void push_scope(const std::string& label) {
        scope_stack.push_back({label, {}, 0, (int)g_tokens.size()});
    }

    std::string push_block_scope() {                    // auto-numbered nested block
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

    void finalize() {                                    // call once, after yyparse() succeeds
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

    SymbolInfo* lookup(const std::string& lexeme) {      // innermost -> outermost
        for (auto it = scope_stack.rbegin(); it != scope_stack.rend(); ++it) {
            auto found = it->symbols.find(lexeme);
            if (found != it->symbols.end()) return &found->second;
        }
        return nullptr;
    }
};
