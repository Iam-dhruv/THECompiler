/* ir.y — Bison grammar for THECompiler's IR generation phase.
 *
 * Parses the source language and populates the scoped symbol table.
 * Three-address code generation will be wired into the grammar actions.
 */

%code requires {
    
    #include "semantic_types.h"
    #include <string>

    struct DeclInfo {
        const char* name = nullptr;
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
#include <sstream>
#include "common.h"
#include "string_pool.h"
#include "scoped_symbol_table.h"

std::vector<TokenRecord> g_tokens;
StringPool g_string_pool;

std::vector<std::string> g_syntax_errors;
bool g_had_lex_error = false;
std::vector<std::string> g_lex_errors;

extern int yylineno;
extern int yylex(void);
extern FILE* yyin;
void yyerror(const char* msg);

ScopedSymbolTable g_symtab;
TypeInfo* g_current_decl_type = nullptr;

// Saved/restored around function parameter lists so nested
// declaration_specifiers reductions don't clobber the outer type.
std::vector<TypeInfo*> g_decl_type_save_stack;

bool g_pending_typedef = false;
std::string g_current_func_name;

%}

%union {
    int token_index;
    TypeInfo* type_info;
    DeclInfo* decl_info;
    int pointer_count;
    int base_kind_val;
}

%token <token_index> T_IDENTIFIER T_INT_CONST T_FLOAT_CONST
%token T_CHAR_CONST T_STRING_LITERAL

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

/* Dangling-else: prefer shift (attach else to nearest if). */
%nonassoc IFX
%nonassoc T_ELSE

%define parse.error verbose

%start program

%%

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
        TypeInfo ret_type = *$1;
        ret_type.pointer_depth = $2->pointer_depth;
        TypeInfo info;
        info.make_function(ret_type);
        g_symtab.insert_global($2->name, info, yylineno, $2->token_index);
        g_current_func_name = $2->name;
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
        g_symtab.push_scope(($1 == BK_STRUCT ? std::string("struct:") : std::string("union:")) + g_tokens[$2].lexeme);
      } T_LBRACE member_decl_list T_RBRACE {
        g_symtab.pop_scope();
        $$ = new TypeInfo{}; $$->base_kind = (BaseKind)$1; $$->set_composite_tag(g_tokens[$2].lexeme);
      }
    | struct_or_union {
        g_symtab.push_scope($1 == BK_STRUCT ? "struct:$anon" : "union:$anon");
      } T_LBRACE member_decl_list T_RBRACE {
        g_symtab.pop_scope();
        $$ = new TypeInfo{}; $$->base_kind = (BaseKind)$1;
      }
    | struct_or_union T_IDENTIFIER {
        $$ = new TypeInfo{}; $$->base_kind = (BaseKind)$1; $$->set_composite_tag(g_tokens[$2].lexeme);
      }
    ;

member_decl_list
    : /* empty */
    | member_decl_list declaration
    ;

enum_specifier
    : T_ENUM T_IDENTIFIER {
        g_symtab.push_scope(std::string("enum:") + g_tokens[$2].lexeme);
      } T_LBRACE enumerator_list T_RBRACE {
        g_symtab.pop_scope();
        $$ = new TypeInfo{}; $$->base_kind = BK_ENUM; $$->set_composite_tag(g_tokens[$2].lexeme);
      }
    | T_ENUM {
        g_symtab.push_scope("enum:$anon");
      } T_LBRACE enumerator_list T_RBRACE {
        g_symtab.pop_scope();
        $$ = new TypeInfo{}; $$->base_kind = BK_ENUM;
      }
    | T_ENUM T_IDENTIFIER {
        $$ = new TypeInfo{}; $$->base_kind = BK_ENUM; $$->set_composite_tag(g_tokens[$2].lexeme);
      }
    ;

enumerator_list
    : enumerator
    | enumerator_list T_COMMA enumerator
    ;

enumerator
    : T_IDENTIFIER {
        TypeInfo info{}; info.base_kind = BK_INT; info.is_const = true;
        g_symtab.insert_global(g_tokens[$1].lexeme, info, yylineno, $1);
      }
    | T_IDENTIFIER T_ASSIGN conditional_expr {
        TypeInfo info{}; info.base_kind = BK_INT; info.is_const = true;
        g_symtab.insert_global(g_tokens[$1].lexeme, info, yylineno, $1);
      }
    ;

class_specifier
    : T_CLASS T_IDENTIFIER {
        g_symtab.push_scope(std::string("class:") + g_tokens[$2].lexeme);
      } T_LBRACE class_member_list T_RBRACE {
        g_symtab.pop_scope();
        $$ = new TypeInfo{}; $$->base_kind = BK_CLASS; $$->set_composite_tag(g_tokens[$2].lexeme);
      }
    | T_CLASS {
        g_symtab.push_scope("class:$anon");
      } T_LBRACE class_member_list T_RBRACE {
        g_symtab.pop_scope();
        $$ = new TypeInfo{}; $$->base_kind = BK_CLASS;
      }
    | T_CLASS T_IDENTIFIER {
        $$ = new TypeInfo{}; $$->base_kind = BK_CLASS; $$->set_composite_tag(g_tokens[$2].lexeme);
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


init_declarator_list
    : init_declarator
    | init_declarator_list T_COMMA init_declarator
    ;
/* distinguishes between a uninitialized declarator and an initialized declaration */
init_declarator
    : declarator {
        if ($1->is_function) {
            TypeInfo ret_type = *g_current_decl_type;
            ret_type.pointer_depth = $1->pointer_depth;
            TypeInfo info;
            info.make_function(ret_type);
            g_symtab.insert_global($1->name, info, yylineno, $1->token_index);
            g_symtab.pop_scope();
        } else {
            TypeInfo info = *g_current_decl_type;
            info.pointer_depth = $1->pointer_depth;
            if ($1->is_array) info.make_array();
            info.is_typedef = g_pending_typedef;
            g_symtab.insert($1->name, info, yylineno, $1->token_index);
        }
      }
    | declarator T_ASSIGN {
        TypeInfo info = *g_current_decl_type;
        info.pointer_depth = $1->pointer_depth;
        if ($1->is_array) info.make_array();
        info.is_typedef = g_pending_typedef;
        g_symtab.insert($1->name, info, yylineno, $1->token_index);
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
        if ($2->is_array) info.make_array();
        g_symtab.insert($2->name, info, yylineno, $2->token_index);
      }
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

/* Statements */

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
    : T_GOTO T_IDENTIFIER T_SEMICOLON
    | T_CONTINUE T_SEMICOLON
    | T_BREAK T_SEMICOLON
    | T_RETURN T_SEMICOLON
    | T_RETURN expr T_SEMICOLON
    ;

labeled_stmt
    : T_IDENTIFIER T_COLON stmt
    ;

/* Expressions — layered precedence (no casts, no sizeof, no comma op). */

primary_expr
    : T_IDENTIFIER              { $$ = $1; }
    | T_INT_CONST               { $$ = -1; }
    | T_FLOAT_CONST             { $$ = -1; }
    | T_CHAR_CONST              { $$ = -1; }
    | T_STRING_LITERAL          { $$ = -1; }
    | T_THIS                    { $$ = -1; }
    | T_LPAREN expr T_RPAREN    { $$ = -1; }
    ;

postfix_expr
    : primary_expr                                     { $$ = $1; }
    | postfix_expr T_LBRACKET expr T_RBRACKET           { $$ = -1; }
    | postfix_expr T_LPAREN T_RPAREN                    { $$ = -1; }
    | postfix_expr T_LPAREN argument_expr_list T_RPAREN { $$ = -1; }
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
        std::cerr << "Lexical errors found; aborting.\n";
        for (const auto& msg : g_lex_errors)
            std::cerr << msg << "\n";
        return 1;
    }

    if (parse_result != 0 || !g_syntax_errors.empty()) {
        std::cerr << "Syntax errors found:\n";
        for (const auto& msg : g_syntax_errors)
            std::cerr << msg << "\n";
        return 1;
    }

    // TODO: Generate three-address code IR and emit output here.

    return 0;
}
