#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# run_parser_tests.sh — Parser-Only Test Runner for THECompiler
#
# Runs all valid and invalid parser/syntax test cases from tests/parser/.
#
# Usage:
#   bash scripts/run_parser_tests.sh
#   bash scripts/run_parser_tests.sh --verbose
#   bash scripts/run_parser_tests.sh --parser-exe ./path/to/parser
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

TESTS_DIR="tests/parser"
PARSER_EXE=""
VERBOSE=false

# ── Parse Arguments ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            echo "Parser Test Runner"
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "  --parser-exe <PATH>  Path to parser executable"
            echo "  -v, --verbose        Display full stdout/stderr for all tests"
            echo "  -h, --help           Show this help message"
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --parser-exe)
            PARSER_EXE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# ── Auto-Detect Executable ──────────────────────────────────────────────────
if [[ -z "$PARSER_EXE" ]]; then
    for p in "./syntax_analyzer" "./syntax_analyzer.exe" "./parser_app" "./parser_app.exe"; do
        if [[ -f "$p" ]]; then
            PARSER_EXE="$p"
            break
        fi
    done
fi

# ── Build If Missing ────────────────────────────────────────────────────────
if [[ -z "$PARSER_EXE" || ! -f "$PARSER_EXE" ]]; then
    echo "Parser binary missing. Building with make..."
    make -f Makefile.parser all 2>/dev/null || true
    for p in "./syntax_analyzer" "./syntax_analyzer.exe"; do
        if [[ -f "$p" ]]; then
            PARSER_EXE="$p"
            break
        fi
    done
fi

if [[ ! -f "$PARSER_EXE" ]]; then
    echo "Error: Parser executable not found. Run 'make parser' first."
    exit 1
fi

# ── Text Normalizer ─────────────────────────────────────────────────────────
normalize_text() {
    sed 's/\r$//' | sed -e :a -e '/^\n*$/{$d;N;};/\n$/ba'
}

# ═════════════════════════════════════════════════════════════════════════════
# RUN PARSER TESTS
# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo " ╔═══════════════════════════════════════════╗"
echo " ║     Syntax Analyzer (Parser) Test Suite   ║"
echo " ╚═══════════════════════════════════════════╝"
echo " Executable : $PARSER_EXE"
echo ""

parse_passed=0
parse_failed=0
parse_total=0

shopt -s nullglob

# ── Valid Syntax Tests ───────────────────────────────────────────────────────
echo "--- Running Valid Syntax Tests (Exit 0 & Token Table Expected) ---"
valid_files=($TESTS_DIR/valid/*.c)
for f in "${valid_files[@]}"; do
    parse_total=$((parse_total + 1))
    name="$(basename "$f")"
    stem="${name%.c}"
    exp_file="$TESTS_DIR/expected/valid/${stem}.txt"

    output=$("$PARSER_EXE" "$f" 2>&1)
    rc=$?

    match_exp=true
    if [[ -f "$exp_file" ]]; then
        exp_norm=$(normalize_text < "$exp_file")
        act_norm=$(echo "$output" | normalize_text)
        if [[ "$exp_norm" != "$act_norm" ]]; then
            match_exp=false
        fi
    fi

    if [[ $rc -eq 0 && "$match_exp" == "true" ]]; then
        parse_passed=$((parse_passed + 1))
        echo "[PASS] $name"
        if [[ "$VERBOSE" == "true" ]]; then echo "$output"; fi
    else
        parse_failed=$((parse_failed + 1))
        echo "[FAIL] $name (exit code: $rc, matched expected: $match_exp)"
        echo "$output"
    fi
done

# ── Invalid Syntax Tests ────────────────────────────────────────────────────
echo ""
echo "--- Running Invalid Syntax Tests (Syntax Error Expected) ---"
invalid_files=($TESTS_DIR/invalid/*.c)
for f in "${invalid_files[@]}"; do
    parse_total=$((parse_total + 1))
    name="$(basename "$f")"
    stem="${name%.c}"
    exp_file="$TESTS_DIR/expected/invalid/${stem}.txt"

    output=$("$PARSER_EXE" "$f" 2>&1)
    rc=$?

    match_exp=true
    if [[ -f "$exp_file" ]]; then
        exp_norm=$(normalize_text < "$exp_file")
        act_norm=$(echo "$output" | normalize_text)
        if [[ "$exp_norm" != "$act_norm" ]]; then
            match_exp=false
        fi
    fi

    if [[ $rc -ne 0 && "$match_exp" == "true" ]]; then
        parse_passed=$((parse_passed + 1))
        echo "[PASS] $name (correctly reported syntax error, exit code: $rc)"
        if [[ "$VERBOSE" == "true" ]]; then echo "$output"; fi
    else
        parse_failed=$((parse_failed + 1))
        echo "[FAIL] $name (exit code: $rc, matched expected: $match_exp)"
        echo "$output"
    fi
done

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo " ┌─────────────────────────────────────────┐"
echo " │ Parser Test Results: $parse_passed / $parse_total passed ($parse_failed failed)"
echo " └─────────────────────────────────────────┘"
echo ""

if [[ $parse_failed -eq 0 ]]; then
    echo " SUCCESS: All $parse_passed parser tests passed!"
    exit 0
else
    echo " FAILURE: $parse_failed parser test(s) failed."
    exit 1
fi
