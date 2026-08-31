/* ============================================================================
 * parser.y — Syntax analyzer (Bison grammar) for the THECompiler source
 * language (the same C/C++-inspired language tokenized by the project's
 * lexical analyzer, https://github.com/Iam-dhruv/THECompiler).
 *
 * This grammar validates the *syntax* of a source program built from the
 * tokens produced by src/lexer.l (a Bison-driven re-implementation of the
 * project's Flex scanner), and additionally performs a semantic
 * classification pass: every identifier token is tagged with what it is
 * (INT_VARIABLE, FUNCTION_DEFINITION(returns:INT), ...) and which scope it
 * appears in, via a scope-stacked symbol table (ScopedSymbolTable, in
 * symbol_table.h). See implementation_plan.md for the full design.
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
 *   - Identifiers after `.`/`->` (member access) are not semantically
 *     classified — this compiler has one flat scope stack, not a per-struct
 *     member namespace, so a real lookup there would silently resolve to an
 *     unrelated same-named symbol. Left as Token_Type == Token_Name.
 *   - A method defined inside a `class`/`struct` body gets its own scope
 *     (its method name), not qualified by the enclosing class/struct name.
 * ==========================================================================*/

%code requires {
    #include "semantic_types.h"
    #include <string>

    struct DeclInfo {
        std::string name;
        int pointer_depth = 0;
        bool is_array = false;
        bool is_function = false;
        int token_index = -1;
    };
}

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
#include "scoped_symbol_table.h"

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

/* ---- Semantic classification state ---- */
ScopedSymbolTable g_symtab;
TypeInfo* g_current_decl_type = nullptr;  // set by declaration_specifiers, read by init_declarator
                                           // (for the outer declaration's own type) and by
                                           // direct_declarator's function-shaped alternatives
                                           // (which save/restore it — see g_decl_type_save_stack)
std::vector<TypeInfo*> g_decl_type_save_stack;
                                           // A function-shaped declarator's own parameter list
                                           // contains nested declaration_specifiers reductions
                                           // (one per parameter) that reuse this SAME global, so
                                           // without saving/restoring around the param list, the
                                           // outer declaration's type (e.g. the VOID of
                                           // "void log_event(char *tag);") would already be
                                           // clobbered by the last parameter's type (CHAR) by the
                                           // time init_declarator reads it back out for the
                                           // prototype's role/return_type.
bool g_pending_typedef = false;           // set by storage_class_specifier, reset per-declaration
std::string g_current_func_name;

/* Corrects an identifier's lookup-derived FUNCTION_DEFINITION/FUNCTION_PROTOTYPE
 * classification to FUNCTION_CALL once postfix_expr discovers it was immediately
 * followed by '(' ... ')'. Functions and void-returning functions aren't
 * distinguished as separate roles — a void function is just a FUNCTION_* whose
 * return type happens to be VOID. */
static void reclassify_as_call(int callee_tok_idx) {
    if (callee_tok_idx < 0) return;                       // callee wasn't a bare identifier
    SymbolInfo* sym = g_symtab.lookup(g_tokens[callee_tok_idx].lexeme);
    if (!sym) { g_tokens[callee_tok_idx].token_type = "FUNCTION_CALL(returns:UNKNOWN)"; return; }
    TypeInfo info = sym->type_info;
    if (info.role != ROLE_FUNC_DEF && info.role != ROLE_FUNC_PROTO) return;  // not a function symbol — leave as-is
    info.role = ROLE_FUNC_CALL;
    g_tokens[callee_tok_idx].token_type = format_semantic_type(info);
}

/* YYSTYPE defaults to int since this grammar performs pure syntax
 * validation and never uses $$ / $n semantic values. Bison itself defines
 * the global `yylval` (non-reentrant mode), so nothing to declare here. */

%}

/* ------------------------------ Tokens ---------------------------------- */
%union {
    int token_index;
    TypeInfo* type_info;
    DeclInfo* decl_info;
    int pointer_count;
    int base_kind_val;
}

%token <token_index> T_IDENTIFIER
%token T_INT_CONST T_FLOAT_CONST T_CHAR_CONST T_STRING_LITERAL

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

%type <type_info>    declaration_specifiers type_specifier
                      struct_or_union_specifier enum_specifier class_specifier
%type <decl_info>    declarator direct_declarator
%type <pointer_count> pointer
%type <base_kind_val> struct_or_union
%type <token_index>  primary_expr postfix_expr

/* Resolve the classic dangling-else shift/reduce conflict: prefer shift
 * (attach the else to the nearest unmatched if). */
%nonassoc IFX
%nonassoc T_ELSE

%define parse.error verbose

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
    : declaration_specifiers declarator {
        TypeInfo info;
        info.return_type = $1->base_kind;
        info.role = ROLE_FUNC_DEF;
        g_symtab.insert_global($2->name, info, yylineno, $2->token_index);
        g_tokens[$2->token_index].token_type = format_semantic_type(info);
        g_current_func_name = $2->name;
        /* the function's own scope is already open — direct_declarator pushed
           it the moment it saw '(' while parsing the parameter list */
      }
      function_body {
        g_symtab.pop_scope();
        g_current_func_name.clear();
      }
    ;

function_body
    : T_LBRACE T_RBRACE
    | T_LBRACE stmt_list T_RBRACE
    ;

/* ------------------------ Declarations / types ---------------------------*/

declaration
    : declaration_specifiers init_declarator_list T_SEMICOLON { g_pending_typedef = false; }
    | declaration_specifiers T_SEMICOLON                      { g_pending_typedef = false; }
    ;

declaration_specifiers
    : type_specifier                                  { $$ = $1; g_current_decl_type = $1; }
    | storage_class_specifier declaration_specifiers  { $$ = $2; g_current_decl_type = $2; }
    ;

storage_class_specifier
    : T_STATIC
    | T_VIRTUAL
    | T_FRIEND
    | T_TYPEDEF { g_pending_typedef = true; }
    ;

type_specifier
    : T_INT    { $$ = new TypeInfo{}; $$->base_kind = BK_INT; }
    | T_CHAR   { $$ = new TypeInfo{}; $$->base_kind = BK_CHAR; }
    | T_FLOAT  { $$ = new TypeInfo{}; $$->base_kind = BK_FLOAT; }
    | T_DOUBLE { $$ = new TypeInfo{}; $$->base_kind = BK_DOUBLE; }
    | T_VOID   { $$ = new TypeInfo{}; $$->base_kind = BK_VOID; }
    | struct_or_union_specifier  { $$ = $1; }
    | enum_specifier             { $$ = $1; }
    | class_specifier            { $$ = $1; }
    ;

struct_or_union
    : T_STRUCT { $$ = BK_STRUCT; }
    | T_UNION  { $$ = BK_UNION; }
    ;

struct_or_union_specifier
    : struct_or_union T_IDENTIFIER {
        g_tokens[$2].token_type = ($1 == BK_STRUCT) ? "STRUCT_TAG" : "UNION_TAG";
        g_symtab.push_scope(($1 == BK_STRUCT ? std::string("struct:") : std::string("union:")) + g_tokens[$2].lexeme);
      } T_LBRACE member_decl_list T_RBRACE {
        g_symtab.pop_scope();
        $$ = new TypeInfo{}; $$->base_kind = (BaseKind)$1; $$->composite_tag = g_tokens[$2].lexeme;
      }
    | struct_or_union {
        g_symtab.push_scope($1 == BK_STRUCT ? "struct:$anon" : "union:$anon");
      } T_LBRACE member_decl_list T_RBRACE {
        g_symtab.pop_scope();
        $$ = new TypeInfo{}; $$->base_kind = (BaseKind)$1;
      }
    | struct_or_union T_IDENTIFIER {
        /* reference to an already-declared tag used as a type — no body, no scope push */
        g_tokens[$2].token_type = ($1 == BK_STRUCT) ? "STRUCT_TAG" : "UNION_TAG";
        $$ = new TypeInfo{}; $$->base_kind = (BaseKind)$1; $$->composite_tag = g_tokens[$2].lexeme;
      }
    ;

member_decl_list
    : /* empty */
    | member_decl_list declaration
    ;

enum_specifier
    : T_ENUM T_IDENTIFIER {
        g_tokens[$2].token_type = "ENUM_TAG";
        g_symtab.push_scope("enum:" + g_tokens[$2].lexeme);
      } T_LBRACE enumerator_list T_RBRACE {
        g_symtab.pop_scope();
        $$ = new TypeInfo{}; $$->base_kind = BK_ENUM; $$->composite_tag = g_tokens[$2].lexeme;
      }
    | T_ENUM {
        g_symtab.push_scope("enum:$anon");
      } T_LBRACE enumerator_list T_RBRACE {
        g_symtab.pop_scope();
        $$ = new TypeInfo{}; $$->base_kind = BK_ENUM;
      }
    | T_ENUM T_IDENTIFIER {
        g_tokens[$2].token_type = "ENUM_TAG";
        $$ = new TypeInfo{}; $$->base_kind = BK_ENUM; $$->composite_tag = g_tokens[$2].lexeme;
      }
    ;

enumerator_list
    : enumerator
    | enumerator_list T_COMMA enumerator
    ;

enumerator
    : T_IDENTIFIER {
        TypeInfo info{}; info.role = ROLE_ENUM_CONST;
        g_symtab.insert_global(g_tokens[$1].lexeme, info, yylineno, $1);
        g_tokens[$1].token_type = "ENUM_CONSTANT";
      }
    | T_IDENTIFIER T_ASSIGN conditional_expr {
        TypeInfo info{}; info.role = ROLE_ENUM_CONST;
        g_symtab.insert_global(g_tokens[$1].lexeme, info, yylineno, $1);
        g_tokens[$1].token_type = "ENUM_CONSTANT";
      }
    ;

class_specifier
    : T_CLASS T_IDENTIFIER {
        g_tokens[$2].token_type = "CLASS_TAG";
        g_symtab.push_scope("class:" + g_tokens[$2].lexeme);
      } T_LBRACE class_member_list T_RBRACE {
        g_symtab.pop_scope();
        $$ = new TypeInfo{}; $$->base_kind = BK_CLASS; $$->composite_tag = g_tokens[$2].lexeme;
      }
    | T_CLASS {
        g_symtab.push_scope("class:$anon");
      } T_LBRACE class_member_list T_RBRACE {
        g_symtab.pop_scope();
        $$ = new TypeInfo{}; $$->base_kind = BK_CLASS;
      }
    | T_CLASS T_IDENTIFIER {
        g_tokens[$2].token_type = "CLASS_TAG";
        $$ = new TypeInfo{}; $$->base_kind = BK_CLASS; $$->composite_tag = g_tokens[$2].lexeme;
      }
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
    : declarator {
        if ($1->is_function) {
            TypeInfo info = *g_current_decl_type;
            info.return_type = info.base_kind;
            info.role = ROLE_FUNC_PROTO;
            g_symtab.insert_global($1->name, info, yylineno, $1->token_index);
            g_tokens[$1->token_index].token_type = format_semantic_type(info);
            g_symtab.pop_scope();   // close the param scope direct_declarator opened — no body
        } else {
            TypeInfo info = *g_current_decl_type;
            info.pointer_depth = $1->pointer_depth;
            info.is_array = $1->is_array;
            info.role = g_pending_typedef ? ROLE_TYPEDEF : ROLE_VARIABLE;
            g_symtab.insert($1->name, info, yylineno, $1->token_index);
            g_tokens[$1->token_index].token_type = format_semantic_type(info);
        }
      }
    | declarator T_ASSIGN {
        /* plain-variable registration only (a function-shaped declarator can't carry an
           initializer in this grammar); done before the initializer is parsed so a
           self-referential initializer can find the declaration */
        TypeInfo info = *g_current_decl_type;
        info.pointer_depth = $1->pointer_depth;
        info.is_array = $1->is_array;
        info.role = g_pending_typedef ? ROLE_TYPEDEF : ROLE_VARIABLE;
        g_symtab.insert($1->name, info, yylineno, $1->token_index);
        g_tokens[$1->token_index].token_type = format_semantic_type(info);
      } initializer
    ;

declarator
    : direct_declarator                    { $$ = $1; }
    | pointer direct_declarator            { $$ = $2; $$->pointer_depth = $1; }
    | T_BIT_AND direct_declarator          { $$ = $2; }
    | pointer T_BIT_AND direct_declarator  { $$ = $3; $$->pointer_depth = $1; }
    ;

pointer
    : T_MUL         { $$ = 1; }
    | T_MUL pointer { $$ = 1 + $2; }
    ;

direct_declarator
    : T_IDENTIFIER {
        $$ = new DeclInfo();
        $$->name = g_tokens[$1].lexeme;
        $$->token_index = $1;
      }
    | T_LPAREN declarator T_RPAREN { $$ = $2; }
    | direct_declarator T_LBRACKET T_RBRACKET { $$ = $1; $$->is_array = true; }
    | direct_declarator T_LBRACKET conditional_expr T_RBRACKET { $$ = $1; $$->is_array = true; }
    | direct_declarator T_LPAREN {
        g_symtab.push_scope($1->name);
        g_decl_type_save_stack.push_back(g_current_decl_type);
      } T_RPAREN {
        $$ = $1; $$->is_function = true;
        g_current_decl_type = g_decl_type_save_stack.back();
        g_decl_type_save_stack.pop_back();
      }
    | direct_declarator T_LPAREN {
        g_symtab.push_scope($1->name);
        g_decl_type_save_stack.push_back(g_current_decl_type);
      } param_list T_RPAREN {
        $$ = $1; $$->is_function = true;
        g_current_decl_type = g_decl_type_save_stack.back();
        g_decl_type_save_stack.pop_back();
      }
    ;

param_list
    : param_decl
    | param_list T_COMMA param_decl
    ;

param_decl
    : declaration_specifiers declarator {
        TypeInfo info = *$1;
        info.pointer_depth = $2->pointer_depth;
        info.is_array = $2->is_array;
        info.role = ROLE_PARAMETER;
        g_symtab.insert($2->name, info, yylineno, $2->token_index);
        g_tokens[$2->token_index].token_type = format_semantic_type(info);
      }
    | declaration_specifiers { /* unnamed parameter — nothing to register */ }
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
    : T_LBRACE { g_symtab.push_block_scope(); } T_RBRACE { g_symtab.pop_scope(); }
    | T_LBRACE { g_symtab.push_block_scope(); } stmt_list T_RBRACE { g_symtab.pop_scope(); }
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
    : T_GOTO T_IDENTIFIER T_SEMICOLON { g_tokens[$2].token_type = "LABEL"; }
    | T_CONTINUE T_SEMICOLON
    | T_BREAK T_SEMICOLON
    | T_RETURN T_SEMICOLON
    | T_RETURN expr T_SEMICOLON
    ;

labeled_stmt
    : T_IDENTIFIER T_COLON stmt { g_tokens[$1].token_type = "LABEL"; }
    ;

/* ------------------------------ Expressions ------------------------------*/
/* Classic layered precedence grammar (no casts, no sizeof, no comma op). */

primary_expr
    : T_IDENTIFIER {
        $$ = $1;
        SymbolInfo* sym = g_symtab.lookup(g_tokens[$1].lexeme);
        g_tokens[$1].token_type = sym ? format_semantic_type(sym->type_info) : "UNDECLARED_IDENTIFIER";
      }
    | T_INT_CONST            { $$ = -1; }
    | T_FLOAT_CONST          { $$ = -1; }
    | T_CHAR_CONST           { $$ = -1; }
    | T_STRING_LITERAL       { $$ = -1; }
    | T_THIS                 { $$ = -1; }
    | T_LPAREN expr T_RPAREN { $$ = -1; }
    ;

postfix_expr
    : primary_expr                                     { $$ = $1; }
    | postfix_expr T_LBRACKET expr T_RBRACKET           { $$ = -1; }
    | postfix_expr T_LPAREN T_RPAREN                    { reclassify_as_call($1); $$ = -1; }
    | postfix_expr T_LPAREN argument_expr_list T_RPAREN { reclassify_as_call($1); $$ = -1; }
    | postfix_expr T_DOT T_IDENTIFIER                   { $$ = -1; }
    | postfix_expr T_ARROW T_IDENTIFIER                 { $$ = -1; }
    | postfix_expr T_INCR                                { $$ = $1; }
    | postfix_expr T_DECR                                { $$ = $1; }
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
    | T_NEW type_specifier T_LBRACKET conditional_expr T_RBRACKET
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
 *   - prints a "Lexeme | Token_Name | Token_Type | Scope" table for the
 *     whole program (success), or
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

    g_symtab.finalize();   // back-fill any leftover top-level ("global") tokens

    std::cout << std::left
              << std::setw(20) << "Lexeme"
              << std::setw(20) << "Token_Name"
              << std::setw(40) << "Token_Type"
              << "Scope\n";
    std::cout << std::string(90, '-') << "\n";
    for (const auto& r : g_tokens) {
        std::cout << std::left
                  << std::setw(20) << r.lexeme
                  << std::setw(20) << r.token_name
                  << std::setw(40) << r.token_type
                  << r.scope << "\n";
    }
    std::cout << "\n" << g_tokens.size() << " token(s). No syntax errors found in '"
               << argv[1] << "'.\n";
    return 0;
}
