#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# run.sh — Run the lexer over every .c file in the tests/ directory
#
# Usage:
#   ./run.sh <path-to-lexer-executable>
#
# Example:
#   ./run.sh ./lexer_app
#
# For each test file the lexer produces three files in out/:
#   out/token_stream_<stem>.txt
#   out/symbol_table_<stem>.txt
#   out/error_log_<stem>.txt
# ─────────────────────────────────────────────────────────────────────────────

LEXER="${1:?Usage: run.sh <path-to-lexer-executable>}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$SCRIPT_DIR/tests"
OUT_DIR="$SCRIPT_DIR/out"

mkdir -p "$OUT_DIR"

CLEAN=0
ERRORS=0
TOTAL=0

echo "Lexer  : $LEXER"
echo "Tests  : $TESTS_DIR"
echo "Output : $OUT_DIR"
echo "────────────────────────────────────────"

for f in "$TESTS_DIR"/*.c; do
    TOTAL=$((TOTAL + 1))
    name="$(basename "$f" .c)"

    if "$LEXER" "$f"; then
        CLEAN=$((CLEAN + 1))
    else
        ERRORS=$((ERRORS + 1))
    fi
done

echo "────────────────────────────────────────"
echo "Done: $CLEAN clean, $ERRORS with errors ($TOTAL total)"
echo "All output files written to: $OUT_DIR/"
