
%{
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <iostream>
#include <string>
#include <unordered_map>
#include "tokens.h"       // Defines TokenType enum   
#include "symbol_table.h"  // Defines SymbolTable and SymbolEntry
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
/* keyword lookup table for all reserved words instead of providing separate lexer, we rely on a simple dictionary lookup*/


%}
%option yylineno
DIGIT       [0-9]
LETTER      [a-zA-Z_]
WHITESPACE  [ \t\r]+
IDENTIFIER  {LETTER}({LETTER}|{DIGIT})*

%x COMMENT  
%x STRING 

%%

    /* Multiline Comments Handling */
"/*"              { BEGIN(COMMENT); }
<COMMENT>"*/"     { BEGIN(INITIAL); }
<COMMENT>\n       { col_num = 1;}
<COMMENT>.        { }
<COMMENT><<EOF>>  { 
                   
                    fprintf(stderr, "Error: unterminated comment (started before line %d)\n", yylineno);
                    yyterminate();

                  }
\/\/.*$           {} /* Single line comments */
\n                {col_num = 1;} 
{WHITESPACE}      {}





    /* Multi-character operators  */
"<<="           { return T_LSHIFT_ASSIGN; }
">>="           { return T_RSHIFT_ASSIGN; }
"+="            { return T_PLUS_ASSIGN; }
"-="            { return T_MINUS_ASSIGN; }
"*="            { return T_MUL_ASSIGN; }
"/="            { return T_DIV_ASSIGN; }
"%="            { return T_MOD_ASSIGN; }
"&="            { return T_AND_ASSIGN; }
"|="            { return T_OR_ASSIGN; }
"^="            { return T_XOR_ASSIGN; }
"<="            { return T_LE; }
">="            { return T_GE; }
"=="            { return T_EQ; }
"!="            { return T_NE; }
"&&"            { return T_AND; }
"||"            { return T_OR; }
"++"            { return T_INCR; }
"--"            { return T_DECR; }
"->"            { return T_ARROW; }
"<<"            { return T_LSHIFT; }
">>"            { return T_RSHIFT; }

    /* Single-character operators and punctuation */
"+"             { return T_PLUS; }
"-"             { return T_MINUS; }
"*"             { return T_MUL; }
"/"             { return T_DIV; }
"%"             { return T_MOD; }
"<"             { return T_LT; }
">"             { return T_GT; }
"="             { return T_ASSIGN; }
"!"             { return T_NOT; }
"&"             { return T_BIT_AND; }
"|"             { return T_BIT_OR; }
"^"             { return T_BIT_XOR; }
"~"             { return T_BIT_NOT; }
";"             { return T_SEMICOLON; }
","             { return T_COMMA; }
"{"             { return T_LBRACE; }
"}"             { return T_RBRACE; }
"("             { return T_LPAREN; }
")"             { return T_RPAREN; }
"["             { return T_LBRACKET; }
"]"             { return T_RBRACKET; }
"."             { return T_DOT; }
"?"             { return T_QUESTION; }
":"             { return T_COLON; }

    /* Literals */
0[xX][0-9a-fA-F]+  { return T_INT_CONST; }
0[0-9]+             {fprintf(stderr,"Error: Invalid Octal literal at line %d\n", yylineno);return T_ERROR;}
0[0-7]+             { return T_INT_CONST; }
0|[1-9][0-9]*       { return T_INT_CONST; }
[0-9]+\.[0-9]+([eE][+-]?[0-9]+)?   { return T_FLOAT_CONST; }  /* 3.14, 3.14e10 */
[0-9]+[eE][+-]?[0-9]+               { return T_FLOAT_CONST; }  /* 3e10 */
'([^\\'\n]|\\[nt\\'])'   { return T_CHAR_CONST; }
'([^\\'\n]|\\[nt\\'])*   { fprintf(stderr, "Error: unterminated char literal at line %d\n", yylineno); return T_ERROR; }
\"                  {
                        str_buf.clear();
                        str_start_line = yylineno;
                        BEGIN(STRING);
                    }

<STRING>\"          {
                        printf("STRING_LITERAL: \"%s\" (line %d)\n", str_buf.c_str(), str_start_line);
                        BEGIN(INITIAL);
                    }

<STRING>\\n         { str_buf += '\n'; }
<STRING>\\t         { str_buf += '\t'; }
<STRING>\\r         { str_buf += '\r'; }
<STRING>\\\\        { str_buf += '\\'; }
<STRING>\\\"        { str_buf += '"';  }

<STRING>\\.         {
                        fprintf(stderr, "Warning: unknown escape '\\%c' at line %d\n", yytext[1], yylineno);
                        str_buf += yytext[1];
                    }

<STRING>\n          {
                        fprintf(stderr, "Error: unterminated string literal starting at line %d\n", str_start_line);
                        BEGIN(INITIAL);
                    }

<STRING>[^\\\n\"]+  { str_buf += yytext; }

<STRING><<EOF>>     {
                      
                        fprintf(stderr, "Error: unterminated string literal starting at line %d\n", str_start_line);
                        yyterminate();

                    }


    /* Identifiers and keywords */
{IDENTIFIER}      {
    auto it = keywords.find(yytext);
    if (it != keywords.end()) {
        return it->second;
    }
    symtab.insert(yytext, T_IDENTIFIER, yylineno);
    return T_IDENTIFIER;
}

    /* Catch-all for illegal characters */
.                 {
                    fprintf(stderr, "Error: unexpected character '%s' at line %d\n", yytext, yylineno);
                    return T_ERROR;
                  }

%%


int yywrap() {
    return 1;
}


int main(int argc, char** argv) {
    int tok;
    FILE* input_file = nullptr;
    std::ofstream output_file;
    std::ostream* output_stream = &std::cout;

    if (argc >= 2) {
        input_file = std::fopen(argv[1], "r");
        if (!input_file) {
            std::perror("Unable to open input file");
            return 1;
        }
        yyin = input_file;
    } else {
        yyin = stdin;
    }

    if (argc >= 3) {
        output_file.open(argv[2]);
        if (!output_file.is_open()) {
            std::perror("Unable to open output file");
            if (input_file) std::fclose(input_file);
            return 1;
        }
        output_stream = &output_file;
    }

    while ((tok = yylex()) != T_EOF) {
        *output_stream << static_cast<TokenType>(tok) << " ";
    }

    if (output_file.is_open()) {
        output_file.close();
    }
    if (input_file) {
        std::fclose(input_file);
    }

    return 0;
}
/* TODO: optional main() for standalone testing of the lexer,
   e.g. loop calling yylex() and print token names until T_EOF */