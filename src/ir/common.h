#pragma once

// Minimal token record — the lexeme pointer points into the global
// StringPool, so no string data is duplicated across records.
struct TokenRecord {
    const char* lexeme;   // interned pointer into StringPool
};
