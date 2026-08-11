#pragma once
#include <ostream>

enum TokenType {
    T_EOF = 0,
    T_ERROR,

    // Identifiers & Literals
    T_IDENTIFIER,       // variable/function names etc.
    T_INT_CONST,        // 123
    T_FLOAT_CONST,      // 3.14, 2.5e10
    T_CHAR_CONST,       // 'a', '\n'
    T_STRING_LITERAL,   // "hello\n"

    // Control Flow Keywords
    T_IF,
    T_ELSE,
    T_FOR,
    T_WHILE,
    T_DO,
    T_UNTIL,
    T_SWITCH,
    T_CASE,
    T_DEFAULT,
    T_BREAK,
    T_CONTINUE,
    T_GOTO,
    T_RETURN,

    // Type Keywords 
    T_INT,
    T_CHAR,
    T_FLOAT,
    T_DOUBLE,
    T_VOID,

    // Composite Type Keywords
    T_STATIC,
    T_STRUCT,
    T_TYPEDEF,
    T_ENUM,
    T_UNION,

    // Class Keywords (just in case)
    T_CLASS,
    T_PUBLIC,
    T_PRIVATE,
    T_PROTECTED,
    T_THIS,
    T_NEW,
    T_DELETE,
    T_VIRTUAL,
    T_FRIEND,

    // Arithmetic Operators
    T_PLUS,          // +
    T_MINUS,         // -
    T_MUL,           // * (also pointer dereferencing)
    T_DIV,           // /
    T_MOD,           // %

    T_INCR,          // ++
    T_DECR,          // --

    // Relational Operators
    T_LT,            // <
    T_GT,            // >
    T_LE,            // <=
    T_GE,            // >=
    T_EQ,            // ==
    T_NE,            // !=

    // Logical Operators
    T_AND,           // &&
    T_OR,            // ||
    T_NOT,           // !

    // Bitwise Operators
    T_BIT_AND,       // &   (also address-of/reference)
    T_BIT_OR,        // |
    T_BIT_XOR,       // ^
    T_BIT_NOT,       // ~
    T_LSHIFT,        // 
    T_RSHIFT,        // >>

    // Assignment Operators 
    T_ASSIGN,        // =
    T_PLUS_ASSIGN,   // +=
    T_MINUS_ASSIGN,  // -=
    T_MUL_ASSIGN,    // *=
    T_DIV_ASSIGN,    // /=
    T_MOD_ASSIGN,    // %=
    T_AND_ASSIGN,    // &=
    T_OR_ASSIGN,     // |=
    T_XOR_ASSIGN,    // ^=
    T_LSHIFT_ASSIGN, // <<=
    T_RSHIFT_ASSIGN, // >>=

    // Member/Pointer Access
    T_ARROW,         // ->
    T_DOT,           // .

    // Ternary
    T_QUESTION,      // ?
    T_COLON,         // :   (also switch/case labels or class inheritance(just in case))

    // Delimiters
    T_SEMICOLON,     // ;
    T_COMMA,         // ,
    T_LBRACE,        // {
    T_RBRACE,        // }
    T_LPAREN,        // (
    T_RPAREN,        // )
    T_LBRACKET,      // [
    T_RBRACKET,      // ]

};

inline std::ostream& operator<<(std::ostream& os, TokenType token) {
    switch (token) {
        case T_IDENTIFIER: return os << "T_IDENTIFIER";
        case T_INT_CONST: return os << "T_INT_CONST";
        case T_FLOAT_CONST: return os << "T_FLOAT_CONST";
        case T_CHAR_CONST: return os << "T_CHAR_CONST";
        case T_STRING_LITERAL: return os << "T_STRING_LITERAL";
        case T_IF: return os << "T_IF";
        case T_ELSE: return os << "T_ELSE";
        case T_FOR: return os << "T_FOR";
        case T_WHILE: return os << "T_WHILE";
        case T_DO: return os << "T_DO";
        case T_UNTIL: return os << "T_UNTIL";
        case T_SWITCH: return os << "T_SWITCH";
        case T_CASE: return os << "T_CASE";
        case T_DEFAULT: return os << "T_DEFAULT";
        case T_BREAK: return os << "T_BREAK";
        case T_CONTINUE: return os << "T_CONTINUE";
        case T_GOTO: return os << "T_GOTO";
        case T_RETURN: return os << "T_RETURN";
        case T_INT: return os << "T_INT";
        case T_CHAR: return os << "T_CHAR";
        case T_FLOAT: return os << "T_FLOAT";
        case T_DOUBLE: return os << "T_DOUBLE";
        case T_VOID: return os << "T_VOID";
        case T_STATIC: return os << "T_STATIC";
        case T_STRUCT: return os << "T_STRUCT";
        case T_TYPEDEF: return os << "T_TYPEDEF";
        case T_ENUM: return os << "T_ENUM";
        case T_UNION: return os << "T_UNION";
        case T_CLASS: return os << "T_CLASS";
        case T_PUBLIC: return os << "T_PUBLIC";
        case T_PRIVATE: return os << "T_PRIVATE";
        case T_PROTECTED: return os << "T_PROTECTED";
        case T_THIS: return os << "T_THIS";
        case T_NEW: return os << "T_NEW";
        case T_DELETE: return os << "T_DELETE";
        case T_VIRTUAL: return os << "T_VIRTUAL";
        case T_FRIEND: return os << "T_FRIEND";
        case T_PLUS: return os << "T_PLUS";
        case T_MINUS: return os << "T_MINUS";
        case T_MUL: return os << "T_MUL";
        case T_DIV: return os << "T_DIV";
        case T_MOD: return os << "T_MOD";
        case T_INCR: return os << "T_INCR";
        case T_DECR: return os << "T_DECR";
        case T_LT: return os << "T_LT";
        case T_GT: return os << "T_GT";
        case T_LE: return os << "T_LE";
        case T_GE: return os << "T_GE";
        case T_EQ: return os << "T_EQ";
        case T_NE: return os << "T_NE";
        case T_AND: return os << "T_AND";
        case T_OR: return os << "T_OR";
        case T_NOT: return os << "T_NOT";
        case T_BIT_AND: return os << "T_BIT_AND";
        case T_BIT_OR: return os << "T_BIT_OR";
        case T_BIT_XOR: return os << "T_BIT_XOR";
        case T_BIT_NOT: return os << "T_BIT_NOT";
        case T_LSHIFT: return os << "T_LSHIFT";
        case T_RSHIFT: return os << "T_RSHIFT";
        case T_ASSIGN: return os << "T_ASSIGN";
        case T_PLUS_ASSIGN: return os << "T_PLUS_ASSIGN";
        case T_MINUS_ASSIGN: return os << "T_MINUS_ASSIGN";
        case T_MUL_ASSIGN: return os << "T_MUL_ASSIGN";
        case T_DIV_ASSIGN: return os << "T_DIV_ASSIGN";
        case T_MOD_ASSIGN: return os << "T_MOD_ASSIGN";
        case T_AND_ASSIGN: return os << "T_AND_ASSIGN";
        case T_OR_ASSIGN: return os << "T_OR_ASSIGN";
        case T_XOR_ASSIGN: return os << "T_XOR_ASSIGN";
        case T_LSHIFT_ASSIGN: return os << "T_LSHIFT_ASSIGN";
        case T_RSHIFT_ASSIGN: return os << "T_RSHIFT_ASSIGN";
        case T_ARROW: return os << "T_ARROW";
        case T_DOT: return os << "T_DOT";
        case T_QUESTION: return os << "T_QUESTION";
        case T_COLON: return os << "T_COLON";
        case T_SEMICOLON: return os << "T_SEMICOLON";
        case T_COMMA: return os << "T_COMMA";
        case T_LBRACE: return os << "T_LBRACE";
        case T_RBRACE: return os << "T_RBRACE";
        case T_LPAREN: return os << "T_LPAREN";
        case T_RPAREN: return os << "T_RPAREN";
        case T_LBRACKET: return os << "T_LBRACKET";
        case T_RBRACKET: return os << "T_RBRACKET";
        case T_EOF: return os << "T_EOF";
        case T_ERROR: return os << "T_ERROR";
    }
    return os << "T_UNKNOWN";
}
