%{
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <iostream>
#include <string>
#include <unordered_map>
#include "tokens.h"
#include "symbol_table.h"

int col_num = 1;
std::string str_buf;
int str_start_line;

#define YY_USER_ACTION \
    token_start_col = col_num; \
    col_num += yyleng;

int token_start_col = 1;

SymbolTable symtab;

static const std::unordered_map<std::string, int> keywords = {
    {"if", T_IF},
    {"else", T_ELSE},
    {"for", T_FOR},
    {"while", T_WHILE},
    {"do", T_DO},
    {"until", T_UNTIL},
    {"switch", T_SWITCH},
    {"case", T_CASE},
    {"default", T_DEFAULT},
    {"break", T_BREAK},
    {"continue", T_CONTINUE},
    {"goto", T_GOTO},
    {"return", T_RETURN},
    {"int", T_INT},
    {"char", T_CHAR},
    {"float", T_FLOAT},
    {"double", T_DOUBLE},
    {"void", T_VOID},
    {"static", T_STATIC},
    {"struct", T_STRUCT},
    {"typedef", T_TYPEDEF},
    {"enum", T_ENUM},
    {"union", T_UNION},
    {"class", T_CLASS},
    {"public", T_PUBLIC},
    {"private", T_PRIVATE},
    {"protected", T_PROTECTED},
    {"this", T_THIS},
    {"new", T_NEW},
    {"delete", T_DELETE},
    {"virtual", T_VIRTUAL},
    {"friend", T_FRIEND}
};
%}

%option yylineno noyywrap

DIGIT        [0-9]
LETTER       [A-Za-z_]
IDENTIFIER   {LETTER}({LETTER}|{DIGIT})*
WHITESPACE   [ \t\r]+
EXP          [eE][+-]?{DIGIT}+
BAD_EXP      [eE][+-]?

%x COMMENT STRING

%%

"/*"                 { BEGIN(COMMENT); }
<COMMENT>"*/"         { BEGIN(INITIAL); }
<COMMENT>\n           { col_num = 1; }
<COMMENT>.            { }
<COMMENT><<EOF>>      { fprintf(stderr, "Error: unterminated comment (started before line %d)\n", yylineno); yyterminate(); }

"//".*               { }
\n                    { col_num = 1; }
{WHITESPACE}          { }

"<<="                { return T_LSHIFT_ASSIGN; }
">>="                { return T_RSHIFT_ASSIGN; }
"+="                 { return T_PLUS_ASSIGN; }
"-="                 { return T_MINUS_ASSIGN; }
"*="                 { return T_MUL_ASSIGN; }
"/="                 { return T_DIV_ASSIGN; }
"%="                 { return T_MOD_ASSIGN; }
"&="                 { return T_AND_ASSIGN; }
"|="                 { return T_OR_ASSIGN; }
"^="                 { return T_XOR_ASSIGN; }
"<="                 { return T_LE; }
">="                 { return T_GE; }
"=="                 { return T_EQ; }
"!="                 { return T_NE; }
"&&"                 { return T_AND; }
"||"                 { return T_OR; }
"++"                 { return T_INCR; }
"--"                 { return T_DECR; }
"->"                 { return T_ARROW; }
"<<"                 { return T_LSHIFT; }
">>"                 { return T_RSHIFT; }

"+"                  { return T_PLUS; }
"-"                  { return T_MINUS; }
"*"                  { return T_MUL; }
"/"                  { return T_DIV; }
"%"                  { return T_MOD; }
"<"                  { return T_LT; }
">"                  { return T_GT; }
"="                  { return T_ASSIGN; }
"!"                  { return T_NOT; }
"&"                  { return T_BIT_AND; }
"|"                  { return T_BIT_OR; }
"^"                  { return T_BIT_XOR; }
"~"                  { return T_BIT_NOT; }
";"                  { return T_SEMICOLON; }
","                  { return T_COMMA; }
"{"                  { return T_LBRACE; }
"}"                  { return T_RBRACE; }
"("                  { return T_LPAREN; }
")"                  { return T_RPAREN; }
"["                  { return T_LBRACKET; }
"]"                  { return T_RBRACKET; }

0[xX][0-9a-fA-F]+    { return T_INT_CONST; }
0[0-9]+              { fprintf(stderr, "Error: Invalid Octal literal at line %d\n", yylineno); return T_ERROR; }
0                    { return T_INT_CONST; }
[1-9][0-9]*          { return T_INT_CONST; }

({DIGIT}+"."{DIGIT}*|"."{DIGIT}+){EXP}?   { return T_FLOAT_CONST; }
{DIGIT}+{EXP}                              { return T_FLOAT_CONST; }

({DIGIT}+"."{DIGIT}*|"."{DIGIT}+){BAD_EXP} { fprintf(stderr, "Error: malformed floating literal at line %d\n", yylineno); return T_ERROR; }
{DIGIT}+{BAD_EXP}                          { fprintf(stderr, "Error: malformed scientific notation at line %d\n", yylineno); return T_ERROR; }

"."                  { return T_DOT; }
"?"                  { return T_QUESTION; }
":"                 { return T_COLON; }

'([^\\'\n]|\\[ntr\\\'\"\\])'  { return T_CHAR_CONST; }
'([^\\'\n]|\\[ntr\\\'\"\\])* { fprintf(stderr, "Error: unterminated char literal at line %d\n", yylineno); return T_ERROR; }

\"                                    { str_buf.clear(); str_start_line = yylineno; BEGIN(STRING); }
<STRING>\"                            { printf("STRING_LITERAL: \"%s\" (line %d)\n", str_buf.c_str(), str_start_line); BEGIN(INITIAL); }
<STRING>\\n                           { str_buf += '\n'; }
<STRING>\\t                           { str_buf += '\t'; }
<STRING>\\r                           { str_buf += '\r'; }
<STRING>\\\\                         { str_buf += '\\'; }
<STRING>\\\"                         { str_buf += '\"'; }
<STRING>\\'                           { str_buf += '\''; }
<STRING>\n                            { fprintf(stderr, "Error: unterminated string literal starting at line %d\n", str_start_line); BEGIN(INITIAL); }
<STRING>[^\\\n\"]+                  { str_buf += yytext; }
<STRING><<EOF>>                       { fprintf(stderr, "Error: unterminated string literal starting at line %d\n", str_start_line); yyterminate(); }

{IDENTIFIER} {
    auto it = keywords.find(yytext);
    if (it != keywords.end()) {
        return it->second;
    }
    symtab.insert(yytext, T_IDENTIFIER, yylineno);
    return T_IDENTIFIER;
}

. {
    fprintf(stderr, "Error: unexpected character '%s' at line %d\n", yytext, yylineno);
    return T_ERROR;
}

%%

int main(int argc, char** argv) {
    int tok;
    FILE* input_file = nullptr;
    bool print_symbols = false;
    int file_arg_index = 1;

    if (argc >= 2 && std::string(argv[1]) == "--symbol-table") {
        print_symbols = true;
        file_arg_index = 2;
    }

    if (argc >= file_arg_index + 1) {
        input_file = std::fopen(argv[file_arg_index], "r");
        if (!input_file) {
            fprintf(stderr, "Could not open file: %s\n", argv[file_arg_index]);
            return 1;
        }
        yyin = input_file;
    } else {
        yyin = stdin;
    }

    while ((tok = yylex()) != T_EOF) {
        if (tok == T_ERROR) {
            continue;
        }
        std::cout << tok << ' ';
    }

    if (print_symbols) {
        symtab.print(std::cout);
    }

    if (input_file) {
        std::fclose(input_file);
    }

    std::cout << '\n';
    return 0;
}