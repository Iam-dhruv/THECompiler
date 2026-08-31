/* ============================================================================
 * parser.y — Syntax analyzer (Bison grammar) for the THECompiler source
 * language (the same C/C++-inspired language tokenized by the project's
 * lexical analyzer, https://github.com/Iam-dhruv/THECompiler).
 *
 * This grammar validates the *syntax* of a source program built from the
 * tokens produced by src/lexer.l (a Bison-driven re-implementation of the
 * project's Flex scanner). It does not perform semantic analysis (type
 * checking, scope resolution, etc.) — that is out of scope for a syntax
 * analyzer.
 *
 * Simplifications (documented, consistent with the project's own stated
 * scope limitations for the lexer):
 *   - No C-style casts and no `sizeof` operator (would require typedef-name
 *     lookahead / lexer feedback to disambiguate from parenthesized
 *     expressions without introducing grammar ambiguity).
 *   - typedef'd names cannot be used later as type specifiers (classic
 *     "typedef-name problem" — needs a symbol table wired into the lexer).
 *     `typedef int Integer;` parses fine; `Integer x;` does not.
 *   - No function-pointer declarators, no comma operator, no varargs.
 *   - `struct`/`union`/`enum`/`class` used as *types* must be written with
 *     their keyword (e.g. `struct Point p;`), matching real C behaviour
 *     without a typedef.
 * ==========================================================================*/

%{
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>
#include <iostream>
#include <iomanip>
#include <sstream>
#include "common.h"

/* ---- Token record collected by the lexer for the final report table ---- */
std::vector<TokenRecord> g_tokens;

/* ---- Error tracking ---- */
std::vector<std::string> g_syntax_errors;
bool g_had_lex_error = false;
std::vector<std::string> g_lex_errors;

extern int yylineno;
extern int yylex(void);
extern FILE* yyin;
void yyerror(const char* msg);

/* YYSTYPE defaults to int since this grammar performs pure syntax
 * validation and never uses $$ / $n semantic values. Bison itself defines
 * the global `yylval` (non-reentrant mode), so nothing to declare here. */

%}

/* ------------------------------ Tokens ---------------------------------- */
%token T_IDENTIFIER T_INT_CONST T_FLOAT_CONST T_CHAR_CONST T_STRING_LITERAL

%token T_IF T_ELSE T_FOR T_WHILE T_DO T_UNTIL T_SWITCH T_CASE T_DEFAULT
%token T_BREAK T_CONTINUE T_GOTO T_RETURN

%token T_INT T_CHAR T_FLOAT T_DOUBLE T_VOID

%token T_STATIC T_STRUCT T_TYPEDEF T_ENUM T_UNION

%token T_CLASS T_PUBLIC T_PRIVATE T_PROTECTED T_THIS T_NEW T_DELETE
%token T_VIRTUAL T_FRIEND

%token T_PLUS T_MINUS T_MUL T_DIV T_MOD T_INCR T_DECR

%token T_LT T_GT T_LE T_GE T_EQ T_NE

%token T_AND T_OR T_NOT

%token T_BIT_AND T_BIT_OR T_BIT_XOR T_BIT_NOT T_LSHIFT T_RSHIFT

%token T_ASSIGN T_PLUS_ASSIGN T_MINUS_ASSIGN T_MUL_ASSIGN T_DIV_ASSIGN
%token T_MOD_ASSIGN T_AND_ASSIGN T_OR_ASSIGN T_XOR_ASSIGN
%token T_LSHIFT_ASSIGN T_RSHIFT_ASSIGN

%token T_ARROW T_DOT T_QUESTION T_COLON

%token T_SEMICOLON T_COMMA T_LBRACE T_RBRACE T_LPAREN T_RPAREN
%token T_LBRACKET T_RBRACKET

/* Resolve the classic dangling-else shift/reduce conflict: prefer shift
 * (attach the else to the nearest unmatched if). */
%nonassoc IFX
%nonassoc T_ELSE

%error-verbose

%start program

%%

/* ----------------------------- Program ----------------------------------*/

program
    : /* empty */
    | program external_decl
    ;

external_decl
    : function_definition
    | declaration
    | error T_SEMICOLON        { yyerrok; }
    | error T_RBRACE           { yyerrok; }
    ;

function_definition
    : declaration_specifiers declarator compound_stmt
    ;

/* ------------------------ Declarations / types ---------------------------*/

declaration
    : declaration_specifiers init_declarator_list T_SEMICOLON
    | declaration_specifiers T_SEMICOLON
    ;

declaration_specifiers
    : type_specifier
    | storage_class_specifier declaration_specifiers
    ;

storage_class_specifier
    : T_STATIC
    | T_VIRTUAL
    | T_FRIEND
    | T_TYPEDEF
    ;

type_specifier
    : T_INT
    | T_CHAR
    | T_FLOAT
    | T_DOUBLE
    | T_VOID
    | struct_or_union_specifier
    | enum_specifier
    | class_specifier
    ;

struct_or_union_specifier
    : struct_or_union T_IDENTIFIER T_LBRACE member_decl_list T_RBRACE
    | struct_or_union T_LBRACE member_decl_list T_RBRACE
    | struct_or_union T_IDENTIFIER
    ;

struct_or_union
    : T_STRUCT
    | T_UNION
    ;

member_decl_list
    : /* empty */
    | member_decl_list declaration
    ;

enum_specifier
    : T_ENUM T_IDENTIFIER T_LBRACE enumerator_list T_RBRACE
    | T_ENUM T_LBRACE enumerator_list T_RBRACE
    | T_ENUM T_IDENTIFIER
    ;

enumerator_list
    : enumerator
    | enumerator_list T_COMMA enumerator
    ;

enumerator
    : T_IDENTIFIER
    | T_IDENTIFIER T_ASSIGN conditional_expr
    ;

class_specifier
    : T_CLASS T_IDENTIFIER T_LBRACE class_member_list T_RBRACE
    | T_CLASS T_LBRACE class_member_list T_RBRACE
    | T_CLASS T_IDENTIFIER
    ;

class_member_list
    : /* empty */
    | class_member_list class_member
    ;

class_member
    : access_specifier T_COLON
    | declaration
    | function_definition
    ;

access_specifier
    : T_PUBLIC
    | T_PRIVATE
    | T_PROTECTED
    ;

/* ----------------------------- Declarators -------------------------------*/

init_declarator_list
    : init_declarator
    | init_declarator_list T_COMMA init_declarator
    ;

init_declarator
    : declarator
    | declarator T_ASSIGN initializer
    ;

declarator
    : direct_declarator
    | pointer direct_declarator
    | T_BIT_AND direct_declarator
    | pointer T_BIT_AND direct_declarator
    ;

pointer
    : T_MUL
    | T_MUL pointer
    ;

direct_declarator
    : T_IDENTIFIER
    | T_LPAREN declarator T_RPAREN
    | direct_declarator T_LBRACKET T_RBRACKET
    | direct_declarator T_LBRACKET conditional_expr T_RBRACKET
    | direct_declarator T_LPAREN T_RPAREN
    | direct_declarator T_LPAREN param_list T_RPAREN
    ;

param_list
    : param_decl
    | param_list T_COMMA param_decl
    ;

param_decl
    : declaration_specifiers declarator
    | declaration_specifiers
    ;

initializer
    : assignment_expr
    | T_LBRACE initializer_list T_RBRACE
    | T_LBRACE initializer_list T_COMMA T_RBRACE
    ;

initializer_list
    : initializer
    | initializer_list T_COMMA initializer
    ;

/* ------------------------------ Statements -------------------------------*/

compound_stmt
    : T_LBRACE T_RBRACE
    | T_LBRACE stmt_list T_RBRACE
    ;

stmt_list
    : stmt
    | stmt_list stmt
    ;

stmt
    : compound_stmt
    | expr_stmt
    | selection_stmt
    | iteration_stmt
    | jump_stmt
    | labeled_stmt
    | declaration
    | error T_SEMICOLON        { yyerrok; }
    ;

expr_stmt
    : T_SEMICOLON
    | expr T_SEMICOLON
    ;

selection_stmt
    : T_IF T_LPAREN expr T_RPAREN stmt %prec IFX
    | T_IF T_LPAREN expr T_RPAREN stmt T_ELSE stmt
    | T_SWITCH T_LPAREN expr T_RPAREN T_LBRACE switch_case_list T_RBRACE
    ;

switch_case_list
    : /* empty */
    | switch_case_list switch_case
    ;

switch_case
    : T_CASE conditional_expr T_COLON stmt_list_opt
    | T_DEFAULT T_COLON stmt_list_opt
    ;

stmt_list_opt
    : /* empty */
    | stmt_list
    ;

iteration_stmt
    : T_WHILE T_LPAREN expr T_RPAREN stmt
    | T_UNTIL T_LPAREN expr T_RPAREN stmt
    | T_DO stmt T_WHILE T_LPAREN expr T_RPAREN T_SEMICOLON
    | T_DO stmt T_UNTIL T_LPAREN expr T_RPAREN T_SEMICOLON
    | T_FOR T_LPAREN for_init expr_stmt for_incr_opt T_RPAREN stmt
    ;

for_init
    : expr_stmt
    | declaration
    ;

for_incr_opt
    : /* empty */
    | expr
    ;

jump_stmt
    : T_GOTO T_IDENTIFIER T_SEMICOLON
    | T_CONTINUE T_SEMICOLON
    | T_BREAK T_SEMICOLON
    | T_RETURN T_SEMICOLON
    | T_RETURN expr T_SEMICOLON
    ;

labeled_stmt
    : T_IDENTIFIER T_COLON stmt
    ;

/* ------------------------------ Expressions ------------------------------*/
/* Classic layered precedence grammar (no casts, no sizeof, no comma op). */

primary_expr
    : T_IDENTIFIER
    | T_INT_CONST
    | T_FLOAT_CONST
    | T_CHAR_CONST
    | T_STRING_LITERAL
    | T_THIS
    | T_LPAREN expr T_RPAREN
    ;

postfix_expr
    : primary_expr
    | postfix_expr T_LBRACKET expr T_RBRACKET
    | postfix_expr T_LPAREN T_RPAREN
    | postfix_expr T_LPAREN argument_expr_list T_RPAREN
    | postfix_expr T_DOT T_IDENTIFIER
    | postfix_expr T_ARROW T_IDENTIFIER
    | postfix_expr T_INCR
    | postfix_expr T_DECR
    ;

argument_expr_list
    : assignment_expr
    | argument_expr_list T_COMMA assignment_expr
    ;

unary_expr
    : postfix_expr
    | T_INCR unary_expr
    | T_DECR unary_expr
    | unary_operator unary_expr
    | T_NEW type_specifier
    | T_NEW type_specifier T_LBRACKET expr T_RBRACKET
    | T_DELETE unary_expr
    | T_DELETE T_LBRACKET T_RBRACKET unary_expr
    ;

unary_operator
    : T_BIT_AND
    | T_MUL
    | T_PLUS
    | T_MINUS
    | T_BIT_NOT
    | T_NOT
    ;

multiplicative_expr
    : unary_expr
    | multiplicative_expr T_MUL unary_expr
    | multiplicative_expr T_DIV unary_expr
    | multiplicative_expr T_MOD unary_expr
    ;

additive_expr
    : multiplicative_expr
    | additive_expr T_PLUS multiplicative_expr
    | additive_expr T_MINUS multiplicative_expr
    ;

shift_expr
    : additive_expr
    | shift_expr T_LSHIFT additive_expr
    | shift_expr T_RSHIFT additive_expr
    ;

relational_expr
    : shift_expr
    | relational_expr T_LT shift_expr
    | relational_expr T_GT shift_expr
    | relational_expr T_LE shift_expr
    | relational_expr T_GE shift_expr
    ;

equality_expr
    : relational_expr
    | equality_expr T_EQ relational_expr
    | equality_expr T_NE relational_expr
    ;

and_expr
    : equality_expr
    | and_expr T_BIT_AND equality_expr
    ;

exclusive_or_expr
    : and_expr
    | exclusive_or_expr T_BIT_XOR and_expr
    ;

inclusive_or_expr
    : exclusive_or_expr
    | inclusive_or_expr T_BIT_OR exclusive_or_expr
    ;

logical_and_expr
    : inclusive_or_expr
    | logical_and_expr T_AND inclusive_or_expr
    ;

logical_or_expr
    : logical_and_expr
    | logical_or_expr T_OR logical_and_expr
    ;

conditional_expr
    : logical_or_expr
    | logical_or_expr T_QUESTION expr T_COLON conditional_expr
    ;

assignment_expr
    : conditional_expr
    | unary_expr assignment_operator assignment_expr
    ;

assignment_operator
    : T_ASSIGN
    | T_PLUS_ASSIGN
    | T_MINUS_ASSIGN
    | T_MUL_ASSIGN
    | T_DIV_ASSIGN
    | T_MOD_ASSIGN
    | T_AND_ASSIGN
    | T_OR_ASSIGN
    | T_XOR_ASSIGN
    | T_LSHIFT_ASSIGN
    | T_RSHIFT_ASSIGN
    ;

expr
    : assignment_expr
    ;

%%

/* ------------------------------ Driver ------------------------------------
 * Reads a source file, runs the parser, and either:
 *   - prints a "Token | Token_Type" table for the whole program (success), or
 *   - reports the lexical / syntax errors that were found.
 * Exit code: 0 on a fully valid program, 1 otherwise.
 * ==========================================================================*/

void yyerror(const char* msg) {
    std::ostringstream oss;
    oss << "Syntax Error at line " << yylineno << ": " << msg;
    g_syntax_errors.push_back(oss.str());
}

int main(int argc, char** argv) {
    if (argc < 2) {
        std::fprintf(stderr, "Usage: %s <source-file>\n", argv[0]);
        return 1;
    }

    FILE* input_file = std::fopen(argv[1], "r");
    if (!input_file) {
        std::perror("Unable to open input file");
        return 1;
    }
    yyin = input_file;

    int parse_result = yyparse();
    std::fclose(input_file);

    if (g_had_lex_error) {
        std::cout << "Lexical errors were found; syntax analysis aborted.\n";
        for (const auto& msg : g_lex_errors) {
            std::cout << msg << "\n";
        }
        return 1;
    }

    if (parse_result != 0 || !g_syntax_errors.empty()) {
        std::cout << "Syntax errors were found in '" << argv[1] << "':\n";
        for (const auto& msg : g_syntax_errors) {
            std::cout << msg << "\n";
        }
        std::cout << g_syntax_errors.size() << " syntax error(s) found.\n";
        return 1;
    }

    std::cout << std::left << std::setw(28) << "Token" << "Token_Type\n";
    std::cout << std::string(48, '-') << "\n";
    for (const auto& r : g_tokens) {
        std::cout << std::left << std::setw(28) << r.lexeme << r.type_name << "\n";
    }
    std::cout << "\n" << g_tokens.size() << " token(s). No syntax errors found in '"
               << argv[1] << "'.\n";
    return 0;
}
