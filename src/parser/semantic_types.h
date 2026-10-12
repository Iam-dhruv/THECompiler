#pragma once
#include <string>

// Semantic classification vocabulary for identifier tokens.

enum BaseKind { BK_INT, BK_CHAR, BK_FLOAT, BK_DOUBLE, BK_VOID,
                BK_STRUCT, BK_UNION, BK_ENUM, BK_CLASS };

enum Role { ROLE_VARIABLE, ROLE_PARAMETER,
            ROLE_FUNC_DEF, ROLE_FUNC_PROTO, ROLE_FUNC_CALL,
            ROLE_TAG, ROLE_ENUM_CONST, ROLE_LABEL, ROLE_TYPEDEF };

struct TypeInfo {
    BaseKind base_kind = BK_INT;
    std::string composite_tag;
    int pointer_depth = 0;
    bool is_array = false;
    Role role = ROLE_VARIABLE;
    BaseKind return_type = BK_VOID;   // only meaningful for FUNC roles
};

inline std::string base_kind_name(BaseKind bk) {
    switch (bk) {
        case BK_INT:    return "INT";
        case BK_CHAR:   return "CHAR";
        case BK_FLOAT:  return "FLOAT";
        case BK_DOUBLE: return "DOUBLE";
        case BK_VOID:   return "VOID";
        case BK_STRUCT: return "STRUCT";
        case BK_UNION:  return "UNION";
        case BK_ENUM:   return "ENUM";
        case BK_CLASS:  return "CLASS";
    }
    return "UNKNOWN";
}

// Renders TypeInfo as the token table's Token_Type column, e.g.
// "INT_VARIABLE", "CHAR_POINTER_PARAMETER", "FUNCTION_CALL(returns:INT)".
inline std::string format_semantic_type(const TypeInfo& info) {
    switch (info.role) {
        case ROLE_FUNC_DEF:
            return "FUNCTION_DEFINITION(returns:" + base_kind_name(info.return_type) + ")";
        case ROLE_FUNC_PROTO:
            return "FUNCTION_PROTOTYPE(returns:" + base_kind_name(info.return_type) + ")";
        case ROLE_FUNC_CALL:
            return "FUNCTION_CALL(returns:" + base_kind_name(info.return_type) + ")";
        case ROLE_TAG:         return "TAG";
        case ROLE_ENUM_CONST:  return "ENUM_CONSTANT";
        case ROLE_LABEL:       return "LABEL";
        case ROLE_TYPEDEF:     return "TYPEDEF_NAME";
        case ROLE_VARIABLE:
        case ROLE_PARAMETER: {
            std::string modifier;
            if (info.is_array) modifier = "_ARRAY";
            else if (info.pointer_depth == 1) modifier = "_POINTER";
            else if (info.pointer_depth >= 2) modifier = "_POINTER_POINTER";
            // Parameters always get _PARAMETER suffix; plain variables use
            // _VARIABLE only when no modifier is present (pointer/array is
            // already unambiguous).
            if (info.role == ROLE_PARAMETER) return base_kind_name(info.base_kind) + modifier + "_PARAMETER";
            if (modifier.empty()) return base_kind_name(info.base_kind) + "_VARIABLE";
            return base_kind_name(info.base_kind) + modifier;
        }
    }
    return "UNKNOWN";
}
