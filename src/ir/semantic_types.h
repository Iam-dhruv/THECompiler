#pragma once
#include <string>
#include <vector>
#include <optional>
#include <memory>

// Type vocabulary for the symbol table. Used by IR generation to know
// types, pointer depths, and roles of declared identifiers.

enum BaseKind { BK_INT, BK_CHAR, BK_FLOAT, BK_DOUBLE, BK_VOID,
                BK_STRUCT, BK_UNION, BK_ENUM, BK_CLASS, BK_ERROR };

// Forward-declare TypeInfo so sub-structs can reference it.
struct TypeInfo;

// Present for functions.
// return_type is a shared_ptr to break the TypeInfo ↔ FunctionTypeInfo cycle.
struct FunctionTypeInfo {
    std::shared_ptr<TypeInfo> return_type;   // full return type (pointer depth, composite, etc.)
    std::vector<TypeInfo> param_types;       // filled during param_decl reductions
};

// Present when the identifier is declared as an array.
struct ArrayTypeInfo {
    int dimension_count = 1; 
    // Future: known sizes for constant-length dimensions
};

// Present for BK_STRUCT / BK_UNION / BK_ENUM / BK_CLASS.
struct CompositeTypeInfo {
    std::string tag;                       // user-supplied tag name (empty = anonymous)
    // Future: member list, base classes, etc.
};

// --- Core type node -----------------------------------------------------

struct TypeInfo {
    BaseKind base_kind     = BK_INT;
    int      pointer_depth = 0;
    bool     is_typedef    = false;
    bool     is_const      = false;

    // Optional payloads — present only when needed.
    std::optional<FunctionTypeInfo>  func_info;       // functions
    std::optional<ArrayTypeInfo>     array_info;      // array declarations
    std::optional<CompositeTypeInfo> composite_info;  // struct/union/enum/class

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

    bool is_numeric() const {
        return (base_kind == BK_CHAR || base_kind == BK_INT ||
                base_kind == BK_FLOAT || base_kind == BK_DOUBLE) && pointer_depth == 0;
    }

    bool is_integral() const {
        return (base_kind == BK_CHAR || base_kind == BK_INT ||
                base_kind == BK_ENUM) && pointer_depth == 0;
    }
    bool is_scalar() const {
        if(pointer_depth>0) return true;
        return is_numeric() || base_kind == BK_ENUM;
    }
    bool is_pointer() const {
        if(pointer_depth > 0 || is_array()) return true; 
    }
    bool is_void() const {
       if( base_kind == BK_VOID && pointer_depth == 0) return true;

    }
    bool is_error() const {
        if(base_kind == BK_ERROR) return true;
    }

};
bool are_types_equal(const TypeInfo& a, const TypeInfo& b){
    if( a.base_kind == b.base_kind && a.pointer_depth == b.pointer_depth)
}
// Expression attributes synthesized during expression type checking
struct ExprInfo {
    TypeInfo type;
    bool is_lvalue = false;
    bool is_const_expr = false;
};


