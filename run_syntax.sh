#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# run.sh — Run the syntax analyzer over every .c file in the tests/ directory
#
# Usage:
#   ./run.sh <path-to-syntax-analyzer-executable>
#
# Example:
#   ./run.sh ./syntax_analyzer
#
# Naming convention for test files (used to check each result automatically):
#   valid_*.c    — expected to be syntactically valid   (exit code 0)
#   invalid_*.c  — expected to contain a syntax error    (exit code != 0)
# ─────────────────────────────────────────────────────────────────────────────

EXE="${1:?Usage: run.sh <path-to-syntax-analyzer-executable>}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$SCRIPT_DIR/tests"

TOTAL=0
MATCH=0
MISMATCH=0

echo "Syntax analyzer : $EXE"
echo "Tests           : $TESTS_DIR"
echo "════════════════════════════════════════════════════════════════"

for f in "$TESTS_DIR"/syntax_*.c; do
    TOTAL=$((TOTAL + 1))
    name="$(basename "$f")"

    echo
    echo "──────────────────────────────────────────────────────────────"
    echo "Test: $name"
    echo "──────────────────────────────────────────────────────────────"
    "$EXE" "$f"
    rc=$?

    if [[ "$name" == syntax_invalid_* ]]; then
        if [[ $rc -ne 0 ]]; then
            echo "[Result: expected a syntax error -> got one -> OK]"
            MATCH=$((MATCH + 1))
        else
            echo "[Result: expected a syntax error -> program parsed cleanly -> MISMATCH]"
            MISMATCH=$((MISMATCH + 1))
        fi
    else
        if [[ $rc -eq 0 ]]; then
            echo "[Result: expected a valid program -> parsed cleanly -> OK]"
            MATCH=$((MATCH + 1))
        else
            echo "[Result: expected a valid program -> got a syntax error -> MISMATCH]"
            MISMATCH=$((MISMATCH + 1))
        fi
    fi
done

echo
echo "════════════════════════════════════════════════════════════════"
echo "Done: $MATCH/$TOTAL matched expectation ($MISMATCH mismatch)"
