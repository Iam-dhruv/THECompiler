#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# run_lexer_tests.sh — Lexer-Only Test Runner for THECompiler
#
# Runs all valid and invalid lexer test cases from tests/lexer/.
#
# Usage:
#   bash scripts/run_lexer_tests.sh
#   bash scripts/run_lexer_tests.sh --verbose
#   bash scripts/run_lexer_tests.sh --lexer-exe ./path/to/lexer
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

TESTS_DIR="tests/lexer"
OUT_DIR="out"
mkdir -p "$OUT_DIR"

LEXER_EXE=""
VERBOSE=false

# ── Parse Arguments ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            echo "Lexer Test Runner"
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "  --lexer-exe <PATH>  Path to lexer executable"
            echo "  -v, --verbose       Display full stdout/stderr for all tests"
            echo "  -h, --help          Show this help message"
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --lexer-exe)
            LEXER_EXE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# ── Auto-Detect Executable ──────────────────────────────────────────────────
if [[ -z "$LEXER_EXE" ]]; then
    for p in "./lexer_app" "./lexer_app.exe"; do
        if [[ -f "$p" ]]; then
            LEXER_EXE="$p"
            break
        fi
    done
fi

# ── Build If Missing ────────────────────────────────────────────────────────
if [[ -z "$LEXER_EXE" || ! -f "$LEXER_EXE" ]]; then
    echo "Lexer binary missing. Building with make..."
    make -f Makefile.lexer all 2>/dev/null || true
    for p in "./lexer_app" "./lexer_app.exe"; do
        if [[ -f "$p" ]]; then
            LEXER_EXE="$p"
            break
        fi
    done
fi

if [[ ! -f "$LEXER_EXE" ]]; then
    echo "Error: Lexer executable not found. Run 'make lexer' first."
    exit 1
fi

# ── Text Normalizer ─────────────────────────────────────────────────────────
normalize_text() {
    sed 's/\r$//' | sed -e :a -e '/^\n*$/{$d;N;};/\n$/ba'
}

# ═════════════════════════════════════════════════════════════════════════════
# RUN LEXER TESTS
# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo " ╔═══════════════════════════════════════════╗"
echo " ║       Lexical Analyzer Test Suite         ║"
echo " ╚═══════════════════════════════════════════╝"
echo " Executable : $LEXER_EXE"
echo ""

lex_passed=0
lex_failed=0
lex_total=0

shopt -s nullglob

# ── Valid Tests ──────────────────────────────────────────────────────────────
echo "--- Running Valid Lexer Tests ---"
valid_files=($TESTS_DIR/valid/*.c)
for f in "${valid_files[@]}"; do
    lex_total=$((lex_total + 1))
    name="$(basename "$f")"
    stem="${name%.c}"
    exp_file="$TESTS_DIR/expected/valid/${stem}.txt"
    ts_file="$OUT_DIR/token_stream_${stem}.txt"

    output=$("$LEXER_EXE" "$f" 2>&1)
    rc=$?

    pass=false
    if [[ -f "$exp_file" && -f "$ts_file" ]]; then
        exp_norm=$(normalize_text < "$exp_file")
        act_norm=$(normalize_text < "$ts_file")
        if [[ "$exp_norm" == "$act_norm" ]]; then
            pass=true
        fi
    else
        if [[ $rc -eq 0 ]]; then pass=true; fi
    fi

    if [[ "$pass" == "true" ]]; then
        lex_passed=$((lex_passed + 1))
        echo "[PASS] $name"
    else
        lex_failed=$((lex_failed + 1))
        echo "[FAIL] $name (exit code: $rc)"
        if [[ "$VERBOSE" == "true" ]]; then echo "$output"; fi
    fi
done

# ── Invalid Tests ────────────────────────────────────────────────────────────
echo ""
echo "--- Running Invalid Lexer Tests ---"
invalid_files=($TESTS_DIR/invalid/*.c)
for f in "${invalid_files[@]}"; do
    lex_total=$((lex_total + 1))
    name="$(basename "$f")"
    stem="${name%.c}"
    exp_file="$TESTS_DIR/expected/invalid/${stem}.txt"
    ts_file="$OUT_DIR/token_stream_${stem}.txt"

    output=$("$LEXER_EXE" "$f" 2>&1)
    rc=$?

    pass=false
    if [[ -f "$exp_file" && -f "$ts_file" ]]; then
        exp_norm=$(normalize_text < "$exp_file")
        act_norm=$(normalize_text < "$ts_file")
        if [[ "$exp_norm" == "$act_norm" ]]; then
            pass=true
        fi
    else
        if [[ $rc -ne 0 ]]; then pass=true; fi
    fi

    if [[ "$pass" == "true" ]]; then
        lex_passed=$((lex_passed + 1))
        echo "[PASS] $name"
    else
        lex_failed=$((lex_failed + 1))
        echo "[FAIL] $name (exit code: $rc)"
        if [[ "$VERBOSE" == "true" ]]; then echo "$output"; fi
    fi
done

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo " ┌─────────────────────────────────────────┐"
echo " │ Lexer Test Results: $lex_passed / $lex_total passed ($lex_failed failed)"
echo " └─────────────────────────────────────────┘"
echo ""

if [[ $lex_failed -eq 0 ]]; then
    echo " SUCCESS: All $lex_passed lexer tests passed!"
    exit 0
else
    echo " FAILURE: $lex_failed lexer test(s) failed."
    exit 1
fi
