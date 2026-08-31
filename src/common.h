#pragma once
#include <string>

/* One recognized token, collected by the lexer and printed as the final
 * "Lexeme | Token_Name | Token_Type | Scope" report table once a program has
 * been confirmed syntactically valid.
 *   lexeme     — the actual source text ("int", "add", "(", "10")
 *   token_name — the generic lexer token category ("T_INT", "T_IDENTIFIER");
 *                set once at lex time, never touched again
 *   token_type — starts equal to token_name; only the parser's identifier
 *                classification actions ever overwrite it (e.g. to
 *                "INT_VARIABLE", "FUNCTION_CALL(returns:INT)")
 *   scope      — starts empty; only ScopedSymbolTable (symbol_table.h) ever
 *                writes it, via pop_scope()'s range back-fill / finalize()
 */
struct TokenRecord {
    std::string lexeme;
    std::string token_name;
    std::string token_type;
    std::string scope;
};
