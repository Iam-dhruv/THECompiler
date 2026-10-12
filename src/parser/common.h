#pragma once
#include <string>

struct TokenRecord {
    std::string lexeme;
    std::string token_name;   // lexer category, e.g. "T_IDENTIFIER"
    std::string token_type;   // starts as token_name; parser may refine to e.g. "INT_VARIABLE"
    std::string scope;        // filled by ScopedSymbolTable::pop_scope() / finalize()
};
