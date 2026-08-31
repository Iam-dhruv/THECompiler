#pragma once
#include <string>

/* ============================================================================
 * semantic_types.h — the parser's semantic classification vocabulary.
 *
 * BaseKind/Role/TypeInfo describe what an identifier *is* (its declared type
 * and the role it plays: a variable, a parameter, a function definition/
 * prototype/call, ...). format_semantic_type() renders a TypeInfo the same
 * way the four-column token table does, e.g. "INT_VARIABLE",
 * "STRUCT_POINTER_PARAMETER", "FUNCTION_DEFINITION(returns:INT)".
 * ==========================================================================*/

enum BaseKind { BK_INT, BK_CHAR, BK_FLOAT, BK_DOUBLE, BK_VOID,
                BK_STRUCT, BK_UNION, BK_ENUM, BK_CLASS };

enum Role { ROLE_VARIABLE, ROLE_PARAMETER,
            ROLE_FUNC_DEF, ROLE_FUNC_PROTO, ROLE_FUNC_CALL,
            ROLE_TAG, ROLE_ENUM_CONST, ROLE_LABEL, ROLE_TYPEDEF };

struct TypeInfo {
    BaseKind base_kind = BK_INT;
    std::string composite_tag;      // "Point", "DataValue", ... (struct/union/enum/class only)
    int pointer_depth = 0;          // 0 = plain, 1 = *, 2 = **
    bool is_array = false;
    Role role = ROLE_VARIABLE;
    BaseKind return_type = BK_VOID; // only meaningful for FUNC roles; BK_VOID means "returns nothing"
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
            // Parameters always keep an explicit _PARAMETER suffix regardless of
            // modifier (INT_PARAMETER, CHAR_POINTER_PARAMETER, INT_ARRAY_PARAMETER).
            // Plain variables keep _VARIABLE only when there's no modifier — a
            // pointer/array variable's modifier already makes it unambiguous
            // (INT_POINTER, INT_ARRAY, not INT_POINTER_VARIABLE).
            if (info.role == ROLE_PARAMETER) return base_kind_name(info.base_kind) + modifier + "_PARAMETER";
            if (modifier.empty()) return base_kind_name(info.base_kind) + "_VARIABLE";
            return base_kind_name(info.base_kind) + modifier;
        }
    }
    return "UNKNOWN";
}
