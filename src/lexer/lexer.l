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

/* ---------------------------------------------------------------------------
 * classify_ppnumber — validate a C "preprocessing number" (C11 §6.4.8).
 *
 * The numeric rules below deliberately OVER-match, using one greedy {PPNUM}
 * pattern, exactly as a real C compiler does: maximal munch first, validate
 * second. That way a malformed literal such as 123abc, 1.2.3.4 or 0x arrives
 * here as a SINGLE token and can be reported as one precise lexical error,
 * instead of silently splitting into several individually-valid tokens
 * (123 + abc) that only surface later as a confusing *syntax* error. The
 * split cannot be undone by the parser, because whitespace is discarded —
 * "123abc" and "123 abc" would be indistinguishable downstream.
 *
 * Returns PPNUM_INT / PPNUM_FLOAT, or PPNUM_BAD after logging a diagnostic.
 * ------------------------------------------------------------------------ */
enum { PPNUM_BAD = 0, PPNUM_INT = 1, PPNUM_FLOAT = 2 };

static bool ppnum_is_digit(char c) { return c >= '0' && c <= '9'; }
static bool ppnum_is_hex(char c) {
    return ppnum_is_digit(c) || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F');
}

static int classify_ppnumber(const char* text, int line) {
    const std::string s(text);

    /* ---- Hexadecimal: 0[xX] then one-or-more hex digits, and nothing else.
       C99 hex floats (0x1p-3) are not supported by this language, so they
       fall through to the invalid-suffix branch. ---------------------------*/
    if (s.size() >= 2 && s[0] == '0' && (s[1] == 'x' || s[1] == 'X')) {
        if (s.size() == 2) {                       /* "0x" with no digits */
            log_error("Error: invalid suffix on numeric constant '%s' at line %d", text, line);
            return PPNUM_BAD;
        }
        for (size_t i = 2; i < s.size(); i++) {
            if (!ppnum_is_hex(s[i])) {
                log_error("Error: invalid suffix on numeric constant '%s' at line %d", text, line);
                return PPNUM_BAD;
            }
        }
        return PPNUM_INT;
    }

    /* ---- More than one '.' can never be a single constant (1.2.3.4). -----*/
    int dots = 0;
    for (size_t i = 0; i < s.size(); i++) if (s[i] == '.') dots++;
    if (dots > 1) {
        log_error("Error: too many decimal points in number '%s' at line %d", text, line);
        return PPNUM_BAD;
    }

    /* ---- Decimal form: digits [ '.' digits ] [ [eE][+-]? digits ] -------*/
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
        if (exp_digits == 0) {                     /* 1e, 1e+, .5e, 1.5e */
            log_error("Error: malformed scientific notation at line %d", line);
            return PPNUM_BAD;
        }
    }

    /* ---- Anything unconsumed is a stray suffix: 123abc, 1_000, 1e5e5. ---*/
    if (i != s.size()) {
        log_error("Error: invalid suffix on numeric constant '%s' at line %d", text, line);
        return PPNUM_BAD;
    }

    if (has_dot || has_exp) return PPNUM_FLOAT;

    /* ---- Plain integer. A leading 0 with more digits is an octal literal,
       which this language does not support (0123, 08, 0777). --------------*/
    if (s.size() > 1 && s[0] == '0') {
        log_error("Error: Invalid Octal literal at line %d", line);
        return PPNUM_BAD;
    }
    return PPNUM_INT;
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

    /* A C "preprocessing number" (C11 6.4.8): starts with a digit, or a '.'
       followed by a digit, then greedily absorbs digits, identifier chars,
       '.', and exponent sign pairs. Deliberately over-broad — every numeric
       form, valid or not, matches here and classify_ppnumber() decides. */
PPNUM       ("."?{DIGIT})({DIGIT}|{LETTER}|"."|[eEpP][+-])*

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

    /* ── Numeric literals ────────────────────────────────────────────────── */
    /* One greedy "preprocessing number" rule (C11 6.4.8), validated by
       classify_ppnumber() above — see that comment for why over-matching
       is deliberate. */
{PPNUM}             {
        int k = classify_ppnumber(yytext, yylineno);
        if (k == PPNUM_INT)   return T_INT_CONST;
        if (k == PPNUM_FLOAT) return T_FLOAT_CONST;
        return T_ERROR;   /* invalid — diagnostic already logged */
    }

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
