%{

#include <cstdio>
#include <cstdarg>
#include <cstdlib>
#include <string>
#include <vector>
#include <unordered_map>
#include "common.h"
#include "parser.tab.h"

extern std::vector<TokenRecord> g_tokens;
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

/* Records the current lexeme/type pair and returns the given token code. */
#define RET(tokcode) \
    do { g_tokens.push_back({std::string(yytext), #tokcode}); return tokcode; } while (0)

/* Same as RET but with an explicitly supplied lexeme (used for strings,
 * whose reconstructed value differs from yytext). */
#define RET_LEXEME(tokcode, lex) \
    do { g_tokens.push_back({(lex), #tokcode}); return tokcode; } while (0)

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

static const std::unordered_map<int, std::string> keyword_names_ = {
    {T_IF, "T_IF"}, {T_ELSE, "T_ELSE"}, {T_FOR, "T_FOR"}, {T_WHILE, "T_WHILE"},
    {T_DO, "T_DO"}, {T_UNTIL, "T_UNTIL"}, {T_SWITCH, "T_SWITCH"}, {T_CASE, "T_CASE"},
    {T_DEFAULT, "T_DEFAULT"}, {T_BREAK, "T_BREAK"}, {T_CONTINUE, "T_CONTINUE"},
    {T_GOTO, "T_GOTO"}, {T_RETURN, "T_RETURN"},
    {T_INT, "T_INT"}, {T_CHAR, "T_CHAR"}, {T_FLOAT, "T_FLOAT"}, {T_DOUBLE, "T_DOUBLE"},
    {T_VOID, "T_VOID"}, {T_STATIC, "T_STATIC"}, {T_STRUCT, "T_STRUCT"},
    {T_TYPEDEF, "T_TYPEDEF"}, {T_ENUM, "T_ENUM"}, {T_UNION, "T_UNION"},
    {T_CLASS, "T_CLASS"}, {T_PUBLIC, "T_PUBLIC"}, {T_PRIVATE, "T_PRIVATE"},
    {T_PROTECTED, "T_PROTECTED"}, {T_THIS, "T_THIS"}, {T_NEW, "T_NEW"},
    {T_DELETE, "T_DELETE"}, {T_VIRTUAL, "T_VIRTUAL"}, {T_FRIEND, "T_FRIEND"}
};
%}

%option yylineno
%option noyywrap

DIGIT       [0-9]
LETTER      [a-zA-Z_]
WHITESPACE  [ \t\r]+
IDENTIFIER  {LETTER}({LETTER}|{DIGIT})*
EXP         [eE][+-]?{DIGIT}+
BAD_EXP     [eE][+-]?

%x COMMENT
%x STRING

%%

    /* Comments */
"/*"              { comment_start_line = yylineno; BEGIN(COMMENT); }
<COMMENT>"*/"     { BEGIN(INITIAL); }
<COMMENT>\n       { }
<COMMENT>.        { }
<COMMENT><<EOF>>  {
                      log_lex_error("Error: unterminated comment starting at line %d", comment_start_line);
                      return 0;
                  }

\/\/.*            { } /* single-line comment */
\n                { }
{WHITESPACE}      { }

    /* Multi-char operators */
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

    /* Single-char operators / punctuation */
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

    /* Integer literals */
0[xX][0-9a-fA-F]+   { RET(T_INT_CONST); }
0[0-9]+             { log_lex_error("Error: Invalid Octal literal at line %d", yylineno); return 0; }
0                   { RET(T_INT_CONST); }
[1-9][0-9]*         { RET(T_INT_CONST); }

    /* Float literals */
{DIGIT}+"."{DIGIT}*{EXP}?          { RET(T_FLOAT_CONST); }
"."{DIGIT}+{EXP}?                  { RET(T_FLOAT_CONST); }
{DIGIT}+{EXP}                      { RET(T_FLOAT_CONST); }

{DIGIT}+"."{DIGIT}*{BAD_EXP}       { log_lex_error("Error: malformed scientific notation at line %d", yylineno); return 0; }
"."{DIGIT}+{BAD_EXP}               { log_lex_error("Error: malformed scientific notation at line %d", yylineno); return 0; }
{DIGIT}+{BAD_EXP}                  { log_lex_error("Error: malformed scientific notation at line %d", yylineno); return 0; }

    /* Char literals */
'([^\\'\n]|\\[ntr\\'\"abfv0])'      { RET(T_CHAR_CONST); }
'([^\\'\n]|\\[ntr\\'\"abfv0]){2,}'  { log_lex_error("Error: multi-character char literal at line %d", yylineno); return 0; }
'([^\\'\n]|\\[ntr\\'\"abfv0])*      { log_lex_error("Error: unterminated char literal at line %d", yylineno); return 0; }

    /* String literals (exclusive STRING state) */
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

    /* Identifiers and keywords */
{IDENTIFIER}      {
    auto it = keywords_.find(yytext);
    if (it != keywords_.end()) {
        g_tokens.push_back({std::string(yytext), keyword_names_.at(it->second)});
        return it->second;
    }
    RET(T_IDENTIFIER);
}

    /* Catch-all for illegal characters */
.                 {
                      log_lex_error("Error: unexpected character '%s' at line %d", yytext, yylineno);
                      return 0;
                  }

%%
