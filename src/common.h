#pragma once
#include <string>

/* One recognized (lexeme, token-type-name) pair, collected by the lexer and
 * printed as the final "Token | Token_Type" report table once a program has
 * been confirmed syntactically valid. */
struct TokenRecord {
    std::string lexeme;
    std::string type_name;
};
