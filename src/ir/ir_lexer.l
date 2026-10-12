%{

#include <cstdio>
#include <cstdarg>
#include <cstdlib>
#include <string>
#include <vector>
#include <unordered_map>
#include "common.h"
#include "string_pool.h"
#include "parser.tab.h"

extern std::vector<TokenRecord> g_tokens;

extern StringPool g_string_pool;
extern bool g_had_lex_error;
extern std::vector<std::string> g_lex_errors;

std::string str_buf;
int str_start_line;
int comment_start_line;

static void log_lex_error(const char* format, ...) {
    char buffer[1024];
    va_list args;
    va_start(args, format);
    vsnprintf(buffer, sizeof(buffer), format, args);
    va_end(args);
    g_lex_errors.push_back(std::string(buffer));
    g_had_lex_error = true;
}

// Validates a C "preprocessing number" (C11 §6.4.8). Uses a single greedy
// PPNUM pattern so malformed literals like 123abc arrive as one token and
// produce one clear error, rather than silently splitting into valid pieces.
enum { PPNUM_BAD = 0, PPNUM_INT = 1, PPNUM_FLOAT = 2 };

static bool ppnum_is_digit(char c) { return c >= '0' && c <= '9'; }
static bool ppnum_is_hex(char c) {
    return ppnum_is_digit(c) || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F');
}

static int classify_ppnumber(const char* text, int line) {
    const std::string s(text);

    // Hexadecimal
    if (s.size() >= 2 && s[0] == '0' && (s[1] == 'x' || s[1] == 'X')) {
        if (s.size() == 2) {
            log_lex_error("Error: invalid suffix on numeric constant '%s' at line %d", text, line);
            return PPNUM_BAD;
        }
        for (size_t i = 2; i < s.size(); i++) {
            if (!ppnum_is_hex(s[i])) {
                log_lex_error("Error: invalid suffix on numeric constant '%s' at line %d", text, line);
                return PPNUM_BAD;
            }
        }
        return PPNUM_INT;
    }

    // Multiple dots (e.g. 1.2.3.4)
    int dots = 0;
    for (size_t i = 0; i < s.size(); i++) if (s[i] == '.') dots++;
    if (dots > 1) {
        log_lex_error("Error: too many decimal points in number '%s' at line %d", text, line);
        return PPNUM_BAD;
    }

    // Decimal: digits [ '.' digits ] [ [eE][+-]? digits ]
    size_t i = 0;
    bool has_dot = false, has_exp = false;

    while (i < s.size() && ppnum_is_digit(s[i])) i++;
    if (i < s.size() && s[i] == '.') {
        has_dot = true; i++;
        while (i < s.size() && ppnum_is_digit(s[i])) i++;
    }
    if (i < s.size() && (s[i] == 'e' || s[i] == 'E')) {
        has_exp = true; i++;
        if (i < s.size() && (s[i] == '+' || s[i] == '-')) i++;
        size_t exp_digits = 0;
        while (i < s.size() && ppnum_is_digit(s[i])) { i++; exp_digits++; }
        if (exp_digits == 0) {
            log_lex_error("Error: malformed scientific notation at line %d", line);
            return PPNUM_BAD;
        }
    }

    // Stray suffix (e.g. 123abc)
    if (i != s.size()) {
        log_lex_error("Error: invalid suffix on numeric constant '%s' at line %d", text, line);
        return PPNUM_BAD;
    }

    if (has_dot || has_exp) return PPNUM_FLOAT;

    // Leading-zero integers are unsupported octal literals
    if (s.size() > 1 && s[0] == '0') {
        log_lex_error("Error: Invalid Octal literal at line %d", line);
        return PPNUM_BAD;
    }
    return PPNUM_INT;
}

// Records an interned lexeme pointer into g_tokens so grammar actions
// can retrieve it via g_tokens[yylval.token_index].lexeme.
#define RET(tokcode) \
    do { g_tokens.push_back({g_string_pool.intern(yytext)}); \
         yylval.token_index = (int)g_tokens.size() - 1; \
         return tokcode; } while (0)

#define RET_LEXEME(tokcode, lex) \
    do { g_tokens.push_back({g_string_pool.intern(lex)}); \
         yylval.token_index = (int)g_tokens.size() - 1; \
         return tokcode; } while (0)



static const std::unordered_map<std::string, int> keywords_ = {
    {"if", T_IF}, {"else", T_ELSE}, {"for", T_FOR}, {"while", T_WHILE},
    {"do", T_DO}, {"until", T_UNTIL}, {"switch", T_SWITCH}, {"case", T_CASE},
    {"default", T_DEFAULT}, {"break", T_BREAK}, {"continue", T_CONTINUE},
    {"goto", T_GOTO}, {"return", T_RETURN},
    {"int", T_INT}, {"char", T_CHAR}, {"float", T_FLOAT}, {"double", T_DOUBLE},
    {"void", T_VOID}, {"static", T_STATIC}, {"struct", T_STRUCT},
    {"typedef", T_TYPEDEF}, {"enum", T_ENUM}, {"union", T_UNION},
    {"class", T_CLASS}, {"public", T_PUBLIC}, {"private", T_PRIVATE},
    {"protected", T_PROTECTED}, {"this", T_THIS}, {"new", T_NEW},
    {"delete", T_DELETE}, {"virtual", T_VIRTUAL}, {"friend", T_FRIEND}
};

%}

%option yylineno
%option noyywrap

DIGIT       [0-9]
LETTER      [a-zA-Z_]
WHITESPACE  [ \t\r]+
IDENTIFIER  {LETTER}({LETTER}|{DIGIT})*

    /* Greedy preprocessing-number pattern; classify_ppnumber() validates. */
PPNUM       ("."?{DIGIT})({DIGIT}|{LETTER}|"."|[eEpP][+-])*

%x COMMENT
%x STRING

%%

"/*"              { comment_start_line = yylineno; BEGIN(COMMENT); }
<COMMENT>"*/"     { BEGIN(INITIAL); }
<COMMENT>\n       { }
<COMMENT>.        { }
<COMMENT><<EOF>>  {
                      log_lex_error("Error: unterminated comment starting at line %d", comment_start_line);
                      return 0;
                  }

\/\/.*            { }
\n                { }
{WHITESPACE}      { }

"<<="           { RET(T_LSHIFT_ASSIGN); }
">>="           { RET(T_RSHIFT_ASSIGN); }
"+="            { RET(T_PLUS_ASSIGN); }
"-="            { RET(T_MINUS_ASSIGN); }
"*="            { RET(T_MUL_ASSIGN); }
"/="            { RET(T_DIV_ASSIGN); }
"%="            { RET(T_MOD_ASSIGN); }
"&="            { RET(T_AND_ASSIGN); }
"|="            { RET(T_OR_ASSIGN); }
"^="            { RET(T_XOR_ASSIGN); }
"<="            { RET(T_LE); }
">="            { RET(T_GE); }
"=="            { RET(T_EQ); }
"!="            { RET(T_NE); }
"&&"            { RET(T_AND); }
"||"            { RET(T_OR); }
"++"            { RET(T_INCR); }
"--"            { RET(T_DECR); }
"->"            { RET(T_ARROW); }
"<<"            { RET(T_LSHIFT); }
">>"            { RET(T_RSHIFT); }

"+"             { RET(T_PLUS); }
"-"             { RET(T_MINUS); }
"*"             { RET(T_MUL); }
"/"             { RET(T_DIV); }
"%"             { RET(T_MOD); }
"<"             { RET(T_LT); }
">"             { RET(T_GT); }
"="             { RET(T_ASSIGN); }
"!"             { RET(T_NOT); }
"&"             { RET(T_BIT_AND); }
"|"             { RET(T_BIT_OR); }
"^"             { RET(T_BIT_XOR); }
"~"             { RET(T_BIT_NOT); }
";"             { RET(T_SEMICOLON); }
","             { RET(T_COMMA); }
"{"             { RET(T_LBRACE); }
"}"             { RET(T_RBRACE); }
"("             { RET(T_LPAREN); }
")"             { RET(T_RPAREN); }
"["             { RET(T_LBRACKET); }
"]"             { RET(T_RBRACKET); }
"."             { RET(T_DOT); }
"?"             { RET(T_QUESTION); }
":"             { RET(T_COLON); }

{PPNUM}             {
        int k = classify_ppnumber(yytext, yylineno);
        if (k == PPNUM_INT)   { RET(T_INT_CONST); }
        if (k == PPNUM_FLOAT) { RET(T_FLOAT_CONST); }
        return 0;
    }

'([^\\'\\n]|\\\\[ntr\\\\'\"abfv0])'      { RET(T_CHAR_CONST); }
'([^\\'\\n]|\\\\[ntr\\\\'\"abfv0]){2,}'  { log_lex_error("Error: multi-character char literal at line %d", yylineno); return 0; }
'([^\\'\\n]|\\\\[ntr\\\\'\"abfv0])*      { log_lex_error("Error: unterminated char literal at line %d", yylineno); return 0; }

\"                  { str_buf.clear(); str_start_line = yylineno; BEGIN(STRING); }

<STRING>\"          {
                        std::string lex = "\"" + str_buf + "\"";
                        BEGIN(INITIAL);
                        RET_LEXEME(T_STRING_LITERAL, lex);
                    }

<STRING>\\n         { str_buf += '\n'; }
<STRING>\\t         { str_buf += '\t'; }
<STRING>\\r         { str_buf += '\r'; }
<STRING>\\\\        { str_buf += '\\'; }
<STRING>\\\"        { str_buf += '"';  }

<STRING>\\.         { str_buf += yytext[1]; }

<STRING>\n          {
                        log_lex_error("Error: unterminated string literal starting at line %d", str_start_line);
                        return 0;
                    }

<STRING>[^\\\n\"]+  { str_buf += yytext; }

<STRING><<EOF>>     {
                        log_lex_error("Error: unterminated string literal starting at line %d", str_start_line);
                        return 0;
                    }

{IDENTIFIER}      {
    auto it = keywords_.find(yytext);
    if (it != keywords_.end()) {
        g_tokens.push_back({g_string_pool.intern(yytext)});
        yylval.token_index = (int)g_tokens.size() - 1;
        return it->second;
    }
    RET(T_IDENTIFIER);
}

.                 {
                      log_lex_error("Error: unexpected character '%s' at line %d", yytext, yylineno);
                      return 0;
                  }

%%
