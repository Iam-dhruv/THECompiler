#pragma once
#include <string>
#include <vector>
#include <optional>
#include <memory>

// Type vocabulary for the symbol table. Used by IR generation to know
// types, pointer depths, and roles of declared identifiers.

enum BaseKind { BK_INT, BK_CHAR, BK_FLOAT, BK_DOUBLE, BK_VOID,
                BK_STRUCT, BK_UNION, BK_ENUM, BK_CLASS };

enum Role { ROLE_VARIABLE, ROLE_PARAMETER,
            ROLE_FUNC_DEF, ROLE_FUNC_PROTO, ROLE_FUNC_CALL,
            ROLE_TAG, ROLE_ENUM_CONST, ROLE_LABEL, ROLE_TYPEDEF };

// --- Sub-structures: only populated when semantically relevant ----------

// Forward-declare TypeInfo so sub-structs can reference it.
struct TypeInfo;

// Present for ROLE_FUNC_DEF / ROLE_FUNC_PROTO / ROLE_FUNC_CALL.
// return_type is a shared_ptr to break the TypeInfo ↔ FunctionTypeInfo cycle.
struct FunctionTypeInfo {
    std::shared_ptr<TypeInfo> return_type;   // full return type (pointer depth, composite, etc.)
    std::vector<TypeInfo> param_types;       // filled during param_decl reductions
};

// Present when the identifier is declared as an array.
struct ArrayTypeInfo {
    int dimension_count = 1;               // number of [] suffixes
    // Future: known sizes for constant-length dimensions
};

// Present for BK_STRUCT / BK_UNION / BK_ENUM / BK_CLASS.
struct CompositeTypeInfo {
    std::string tag;                       // user-supplied tag name (empty = anonymous)
    // Future: member list, base classes, etc.
};

// --- Core type node -----------------------------------------------------

struct TypeInfo {
    BaseKind base_kind   = BK_INT;
    int      pointer_depth = 0;
    Role     role        = ROLE_VARIABLE;

    // Optional payloads — present only when the role/kind demands it.
    std::optional<FunctionTypeInfo>  func_info;       // ROLE_FUNC_*
    std::optional<ArrayTypeInfo>     array_info;       // array declarations
    std::optional<CompositeTypeInfo> composite_info;   // struct/union/enum/class

    // ---- Convenience helpers -------------------------------------------

    bool is_array()    const { return array_info.has_value(); }
    bool is_function() const { return func_info.has_value(); }

    void make_array(int dims = 1) {
        array_info = ArrayTypeInfo{dims};
    }

    void make_function(const TypeInfo& ret) {
        func_info = FunctionTypeInfo{std::make_shared<TypeInfo>(ret), {}};
    }

    void set_composite_tag(const std::string& tag) {
        composite_info = CompositeTypeInfo{tag};
    }
};
