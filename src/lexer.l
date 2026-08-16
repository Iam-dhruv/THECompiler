%{
#include <cstdio>
#include <cstdarg>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <string>
#include <unordered_map>
#include <vector>
#ifdef _WIN32
#  include <direct.h>
#  define make_dir(p) _mkdir(p)
#else
#  include <sys/stat.h>
#  define make_dir(p) mkdir((p), 0755)
#endif
#include "tokens.h"        // Defines TokenType enum
#include "symbol_table.h"  // Defines SymbolTable and SymbolEntry
int col_num = 1;
std::string str_buf;
int str_start_line;
int comment_start_line;   // line where the current /* comment opened

/* YY_USER_ACTION runs before every rule action.
   We use it to snapshot the current lexeme (yytext) for the token table.
   String literals override this later with the reconstructed full string. */
#define YY_USER_ACTION \
    token_start_col = col_num; \
    col_num += yyleng; \
    current_lexeme = yytext;

int token_start_col = 1;

/* Lexeme / error tracking globals */
std::string current_lexeme;            // set by YY_USER_ACTION; overridden for strings
std::vector<std::string> error_log;    // all collected error/warning messages
bool had_error = false;

void log_error(const char* format, ...) {
    char buffer[1024];
    va_list args;
    va_start(args, format);
    vsnprintf(buffer, sizeof(buffer), format, args);
    va_end(args);
    error_log.push_back(std::string(buffer));
    had_error = true;
}

/* Symbol table */
SymbolTable symtab;
static const std::unordered_map<std::string, int> keywords = {
    {"if",        T_IF},       {"else",      T_ELSE},
    {"for",       T_FOR},      {"while",     T_WHILE},
    {"do",        T_DO},       {"until",     T_UNTIL},
    {"switch",    T_SWITCH},   {"case",      T_CASE},
    {"default",   T_DEFAULT},  {"break",     T_BREAK},
    {"continue",  T_CONTINUE}, {"goto",      T_GOTO},
    {"return",    T_RETURN},
    {"int",       T_INT},      {"char",      T_CHAR},
    {"float",     T_FLOAT},    {"double",    T_DOUBLE},
    {"void",      T_VOID},     {"static",    T_STATIC},
    {"struct",    T_STRUCT},   {"typedef",   T_TYPEDEF},
    {"enum",      T_ENUM},     {"union",     T_UNION},
    {"class",     T_CLASS},    {"public",    T_PUBLIC},
    {"private",   T_PRIVATE},  {"protected", T_PROTECTED},
    {"this",      T_THIS},     {"new",       T_NEW},
    {"delete",    T_DELETE},   {"virtual",   T_VIRTUAL},
    {"friend",    T_FRIEND}
};
/* keyword lookup table for all reserved words instead of providing separate lexer, we rely on a simple dictionary lookup*/


%}

%option yylineno
DIGIT       [0-9]
LETTER      [a-zA-Z_]
WHITESPACE  [ \t\r]+
IDENTIFIER  {LETTER}({LETTER}|{DIGIT})*
EXP         [eE][+-]?{DIGIT}+
BAD_EXP     [eE][+-]?

%x COMMENT
%x STRING

%%

    /* Multiline comments */
"/*"              { comment_start_line = yylineno; BEGIN(COMMENT); }
<COMMENT>"*/"     { BEGIN(INITIAL); }
<COMMENT>\n       { col_num = 1; }
<COMMENT>.        { }
<COMMENT><<EOF>>  {
                      log_error("Error: unterminated comment starting at line %d", comment_start_line);
                      yyterminate();
                  }

\/\/.*$           {} /* Single-line comment — consume to end of line */
\n                { col_num = 1; }
{WHITESPACE}      {}

    /* Multi char operators*/
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

    /* Single char operators and punctuation */
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

    /* Integer literals */
    /* Hex first (distinct 0x prefix); bare 0 accepted; multi-digit
       leading-zero is rejected as invalid/unsupported octal. */
0[xX][0-9a-fA-F]+   { return T_INT_CONST; }
0[0-9]+             { log_error("Error: Invalid Octal literal at line %d", yylineno); return T_ERROR; }
0                    { return T_INT_CONST; }
[1-9][0-9]*          { return T_INT_CONST; }

    /* ── Float literals ─────────────────────────────────────────────────── */
    /* Valid forms: 1.0  1.  .1  1e10  2.5e-3  .5e+2
       BAD_EXP rules fire only when no digits follow [eE][+-]? */
{DIGIT}+"."{DIGIT}*{EXP}?          { return T_FLOAT_CONST; }  /* 1., 1.0, 1.0e10 */
"."{DIGIT}+{EXP}?                  { return T_FLOAT_CONST; }  /* .1, .1e10 */
{DIGIT}+{EXP}                      { return T_FLOAT_CONST; }  /* 1e10 */

{DIGIT}+"."{DIGIT}*{BAD_EXP}       { log_error("Error: malformed scientific notation at line %d", yylineno); return T_ERROR; }
"."{DIGIT}+{BAD_EXP}               { log_error("Error: malformed scientific notation at line %d", yylineno); return T_ERROR; }
{DIGIT}+{BAD_EXP}                  { log_error("Error: malformed scientific notation at line %d", yylineno); return T_ERROR; }

    /* ── Char literals ──────────────────────────────────────────────────── */
    /* Supported escapes: \n \t \r \\ \' \" \a \b \f \v \0               */
'([^\\'\n]|\\[ntr\\'\"abfv0])'      { return T_CHAR_CONST; }
'([^\\'\n]|\\[ntr\\'\"abfv0]){2,}'  { log_error("Error: multi-character char literal at line %d", yylineno); return T_ERROR; }
'([^\\'\n]|\\[ntr\\'\"abfv0])*      { log_error("Error: unterminated char literal at line %d", yylineno); return T_ERROR; }

    /* ── String literals (exclusive STRING state) ────────────────────────── */
\"                  {
                        str_buf.clear();
                        str_start_line = yylineno;
                        BEGIN(STRING);
                    }

<STRING>\"          {
                        /* Override the lexeme set by YY_USER_ACTION with the
                           full reconstructed quoted string. */
                        current_lexeme = "\"" + str_buf + "\"";
                        BEGIN(INITIAL);
                        return T_STRING_LITERAL;
                    }

<STRING>\\n         { str_buf += '\n'; }
<STRING>\\t         { str_buf += '\t'; }
<STRING>\\r         { str_buf += '\r'; }
<STRING>\\\\        { str_buf += '\\'; }
<STRING>\\\"        { str_buf += '"';  }

<STRING>\\.         {
                        log_error("Warning: unknown escape '\\%c' in string at line %d", yytext[1], yylineno);
                        str_buf += yytext[1];
                    }

<STRING>\n          {
                        log_error("Error: unterminated string literal starting at line %d", str_start_line);
                        col_num = 1;               /* reset column — YY_USER_ACTION already incremented it */
                        BEGIN(INITIAL);
                        return T_ERROR;
                    }

<STRING>[^\\\n\"]+  { str_buf += yytext; }

<STRING><<EOF>>     {
                        log_error("Error: unterminated string literal starting at line %d", str_start_line);
                        yyterminate();
                    }

    /* ── Identifiers and keywords ─────────────────────────────────────── */
{IDENTIFIER}      {
    auto it = keywords.find(yytext);
    if (it != keywords.end()) {
        return it->second;
    }
    symtab.insert(yytext, T_IDENTIFIER, yylineno);
    return T_IDENTIFIER;
}

    /* ── Catch-all for illegal characters ──────────────────────────────── */
.                 {
                      log_error("Error: unexpected character '%s' at line %d", yytext, yylineno);
                      return T_ERROR;
                  }

%%

int yywrap() { return 1; }

/* ════════════════════════════════════════════════════════════════════════════
   main()
   ──────
   Reads one source file (or stdin), lexes it, then writes three output files
   under out/ (created if missing):

     out/token_stream_<stem>.txt   — two-column table: Lexeme | Token
     out/symbol_table_<stem>.txt   — identifier symbol table
     out/error_log_<stem>.txt      — all collected errors / warnings

   Exits 0 if no errors, 1 if any lexical error was found.
   ════════════════════════════════════════════════════════════════════════════ */
int main(int argc, char** argv) {
    FILE* input_file   = nullptr;
    int   file_arg_idx = 1;

    /* Legacy flag kept for backward compatibility */
    if (argc >= 2 && std::string(argv[1]) == "--symbol-table") {
        file_arg_idx = 2;
    }

    /* ── Open input ──────────────────────────────────────────────────────── */
    std::string stem = "stdin";
    if (argc >= file_arg_idx + 1) {
        input_file = std::fopen(argv[file_arg_idx], "r");
        if (!input_file) {
            std::perror("Unable to open input file");
            return 1;
        }
        yyin = input_file;

        /* Extract stem: strip directory path and file extension.
           e.g.  "../tests/valid_basic.c"  →  "valid_basic"           */
        std::string path = argv[file_arg_idx];
        auto slash = path.find_last_of("/\\");
        std::string base = (slash != std::string::npos) ? path.substr(slash + 1) : path;
        auto dot = base.rfind('.');
        stem = (dot != std::string::npos) ? base.substr(0, dot) : base;
    } else {
        yyin = stdin;
    }

    /* ── Create out/ directory ───────────────────────────────────────────── */
    make_dir("out");   /* silently ignored if already exists */

    const std::string ts_path  = "out/token_stream_"  + stem + ".txt";
    const std::string sym_path = "out/symbol_table_"  + stem + ".txt";
    const std::string err_path = "out/error_log_"     + stem + ".txt";

    /* ── Lex the entire file, collect valid tokens ───────────────────────── */
    struct TokenRecord { std::string lexeme; int tok; };
    std::vector<TokenRecord> tokens;
    int tok;
    while ((tok = yylex()) != T_EOF) {
        if (tok == T_ERROR) continue;
        tokens.push_back({ current_lexeme, tok });
    }

    /* ── Print the token table to stdout for valid source files ─────────── */
    if (!had_error) {
        std::cout << std::left << std::setw(28) << "Lexeme" << "Token\n";
        std::cout << std::string(48, '-') << "\n";
        for (const auto& r : tokens) {
            std::ostringstream tname;
            tname << static_cast<TokenType>(r.tok);
            std::cout << std::left << std::setw(28) << r.lexeme
                      << tname.str() << "\n";
        }
    } else {
        for (const auto& msg : error_log) {
            std::cout << msg << "\n";
        }
    }

    /* ── Write token_stream file ─────────────────────────────────────────── */
    {
        std::ofstream ts(ts_path);
        if (had_error) {
            ts << "NOTE: Lexical errors were found. Token stream may be incomplete.\n";
            ts << "      See: " << err_path << "\n\n";
        }
        /* Two-column table */
        ts << std::left << std::setw(28) << "Lexeme" << "Token\n";
        ts << std::string(48, '-') << "\n";
        for (auto& r : tokens) {
            /* Use the existing operator<< from tokens.h to get the real enum name. */
        std::ostringstream tname;
        tname << static_cast<TokenType>(r.tok);
        ts << std::left << std::setw(28) << r.lexeme
           << tname.str() << "\n";
        }
    }

    /* ── Write symbol_table file ─────────────────────────────────────────── */
    {
        std::ofstream sym(sym_path);
        symtab.print(sym);
    }

    /* ── Write error_log file ────────────────────────────────────────────── */
    {
        std::ofstream err(err_path);
        if (error_log.empty()) {
            err << "No lexical errors.\n";
        } else {
            for (auto& msg : error_log) {
                err << msg << "\n";
            }
        }
    }

    /* ── Console summary (brief) ─────────────────────────────────────────── */
    if (had_error) {
        std::cerr << "[ERRORS] " << error_log.size() << " error(s) in '"
                  << stem << "'. See " << err_path << "\n";
    } else {
        std::cout << "[OK] " << tokens.size() << " token(s) in '"
                  << stem << "'. Output: " << ts_path << "\n";
    }

    if (input_file) std::fclose(input_file);
    return had_error ? 1 : 0;
}
