#pragma once
#include <unordered_map>
#include <string>
#include "tokens.h"

struct SymbolEntry {
    std::string lexeme;
    TokenType token_type;
    int declared_line;
    int usage_count = 0;
};

class SymbolTable {
private:
    std::unordered_map<std::string, SymbolEntry> table; // currently keeping flat scope; different scopes handled in later phases

public:
    SymbolEntry& insert(const std::string& lexeme, TokenType token_type, int line) {
        auto it = table.find(lexeme);
        if (it != table.end()) {
            it->second.usage_count++;
            return it->second;
        }
        SymbolEntry entry{lexeme, token_type, line, 0};
        auto [inserted_it, success] = table.emplace(lexeme, std::move(entry));
        return inserted_it->second;
    }

    SymbolEntry* lookup(const std::string& lexeme) {
        auto it = table.find(lexeme);
        return (it != table.end()) ? &it->second : nullptr;
    }
};