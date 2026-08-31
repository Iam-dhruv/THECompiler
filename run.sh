#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# run.sh — Unified Cross-Platform Test Runner for THECompiler
#
# Works on Linux, macOS, Windows (Git Bash, MSYS2, WSL, Cygwin).
#
# Usage:
#   ./run.sh                    Run ALL test cases (Lexer + Parser) [Default]
#   ./run.sh --all              Run ALL test cases
#   ./run.sh --lexer, -l        Run Lexer test cases only
#   ./run.sh --parser, -p       Run Parser (Syntax) test cases only
#   ./run.sh --help, -h         Show help and usage options
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

TESTS_DIR="tests"
OUT_DIR="out"
mkdir -p "$OUT_DIR"

# ── Parse Arguments ──────────────────────────────────────────────────────────
SUITE="all"
LEXER_EXE=""
PARSER_EXE=""
VERBOSE=false

show_help() {
    echo "THECompiler Unified Test Runner"
    echo "Usage: ./run.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  (no args)             Run ALL test suites (Lexer + Parser)"
    echo "  -a, --all, all        Run ALL test suites"
    echo "  -l, --lexer, lexer    Run Lexer test suite only"
    echo "  -p, --parser, parser  Run Parser (Syntax) test suite only"
    echo "  --syntax, syntax      Alias for --parser"
    echo "  --lexer-exe <PATH>    Path to lexer executable"
    echo "  --parser-exe <PATH>   Path to parser executable"
    echo "  -v, --verbose         Display full stdout/stderr for all tests"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./run.sh"
    echo "  ./run.sh --lexer"
    echo "  ./run.sh --parser"
    echo "  ./run.sh -p --verbose"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help|help)
            show_help
            ;;
        -l|--lexer|lexer)
            SUITE="lexer"
            shift
            ;;
        -p|--parser|parser|--syntax|syntax)
            SUITE="parser"
            shift
            ;;
        -a|--all|all)
            SUITE="all"
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --lexer-exe)
            LEXER_EXE="$2"
            shift 2
            ;;
        --parser-exe)
            PARSER_EXE="$2"
            shift 2
            ;;
        *)
            if [[ -f "$1" || -f "$1.exe" ]]; then
                if [[ "$1" == *lexer* ]]; then
                    LEXER_EXE="$1"
                    SUITE="lexer"
                else
                    PARSER_EXE="$1"
                    SUITE="parser"
                fi
            else
                echo "Unknown option: $1"
                echo "Run './run.sh --help' for available options."
                exit 1
            fi
            shift
            ;;
    esac
done

# ── Auto-Detect Executables ──────────────────────────────────────────────────
find_executable() {
    local base_name="$1"
    local paths=("./$base_name" "./$base_name.exe" "./src/$base_name" "./src/$base_name.exe")
    for p in "${paths[@]}"; do
        if [[ -f "$p" ]]; then
            echo "$p"
            return 0
        fi
    done
    return 1
}

if [[ -z "$LEXER_EXE" ]]; then
    LEXER_EXE=$(find_executable "lexer_app") || LEXER_EXE="./lexer_app.exe"
fi

if [[ -z "$PARSER_EXE" ]]; then
    PARSER_EXE=$(find_executable "syntax_analyzer") || PARSER_EXE=$(find_executable "parser_app") || PARSER_EXE="./syntax_analyzer.exe"
fi

# ── Build If Missing ────────────────────────────────────────────────────────
build_if_needed() {
    if [[ "$SUITE" == "lexer" || "$SUITE" == "all" ]]; then
        if [[ ! -f "$LEXER_EXE" && ! -f "${LEXER_EXE}.exe" ]]; then
            echo "Lexer binary missing. Building with make..."
            make lexer_app 2>/dev/null || true
        fi
    fi
    if [[ "$SUITE" == "parser" || "$SUITE" == "all" ]]; then
        if [[ ! -f "$PARSER_EXE" && ! -f "${PARSER_EXE}.exe" ]]; then
            echo "Parser binary missing. Building with make..."
            make syntax_analyzer 2>/dev/null || true
        fi
    fi
}
build_if_needed

# ── Text Normalizer ──────────────────────────────────────────────────────────
normalize_text() {
    sed 's/\r$//' | sed -e :a -e '/^\n*$/{$d;N;};/\n$/ba'
}

TOTAL_RUN=0
TOTAL_PASSED=0
TOTAL_FAILED=0

# ═════════════════════════════════════════════════════════════════════════════
# 1. RUN LEXER TESTS
# ═════════════════════════════════════════════════════════════════════════════
run_lexer_suite() {
    echo ""
    echo " [SUITE 1/2] Lexical Analyzer Tests"
    echo " Executable : $LEXER_EXE"
    echo " Tests Dir  : $TESTS_DIR"
    echo ""

    if [[ ! -f "$LEXER_EXE" && ! -f "${LEXER_EXE}.exe" ]]; then
        echo "Error: Lexer executable '$LEXER_EXE' not found. Run 'make lexer_app' first."
        return 1
    fi

    local lex_passed=0
    local lex_failed=0
    local lex_total=0

    shopt -s nullglob
    local lex_files=($TESTS_DIR/valid_*.c $TESTS_DIR/invalid_*.c)

    for f in "${lex_files[@]}"; do
        lex_total=$((lex_total + 1))
        local name="$(basename "$f")"
        local stem="${name%.c}"
        local exp_file="$TESTS_DIR/expected/${stem}.txt"
        local ts_file="$OUT_DIR/token_stream_${stem}.txt"

        local output
        output=$("$LEXER_EXE" "$f" 2>&1)
        local rc=$?

        local pass=false
        if [[ -f "$exp_file" && -f "$ts_file" ]]; then
            local exp_norm
            local act_norm
            exp_norm=$(normalize_text < "$exp_file")
            act_norm=$(normalize_text < "$ts_file")
            if [[ "$exp_norm" == "$act_norm" ]]; then
                pass=true
            fi
        else
            if [[ "$name" == invalid_* ]]; then
                if [[ $rc -ne 0 ]]; then pass=true; fi
            else
                if [[ $rc -eq 0 ]]; then pass=true; fi
            fi
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

    echo ""
    echo " Lexer Suite Results: $lex_passed / $lex_total passed ($lex_failed failed)"
    echo ""

    TOTAL_RUN=$((TOTAL_RUN + lex_total))
    TOTAL_PASSED=$((TOTAL_PASSED + lex_passed))
    TOTAL_FAILED=$((TOTAL_FAILED + lex_failed))
}

# ═════════════════════════════════════════════════════════════════════════════
# 2. RUN PARSER TESTS
# ═════════════════════════════════════════════════════════════════════════════
run_parser_suite() {
    echo ""
    echo " [SUITE 2/2] Syntax Analyzer (Parser) Tests"
    echo " Executable : $PARSER_EXE"
    echo " Tests Dir  : $TESTS_DIR"
    echo ""

    if [[ ! -f "$PARSER_EXE" && ! -f "${PARSER_EXE}.exe" ]]; then
        echo "Error: Parser executable '$PARSER_EXE' not found. Run 'make syntax_analyzer' first."
        return 1
    fi

    local parse_passed=0
    local parse_failed=0
    local parse_total=0

    shopt -s nullglob
    local valid_files=($TESTS_DIR/syntax_valid_*.c)
    local invalid_files=($TESTS_DIR/syntax_invalid_*.c)

    echo "--- Running Valid Syntax Tests (Exit 0 & Token Table Expected) ---"
    for f in "${valid_files[@]}"; do
        parse_total=$((parse_total + 1))
        local name="$(basename "$f")"
        local stem="${name%.c}"
        local exp_file="$TESTS_DIR/expected/${stem}.txt"

        local output
        output=$("$PARSER_EXE" "$f" 2>&1)
        local rc=$?

        local match_exp=true
        if [[ -f "$exp_file" ]]; then
            local exp_norm
            local act_norm
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

    echo ""
    echo "--- Running Invalid Syntax Tests (Syntax Error Expected) ---"
    for f in "${invalid_files[@]}"; do
        parse_total=$((parse_total + 1))
        local name="$(basename "$f")"
        local stem="${name%.c}"
        local exp_file="$TESTS_DIR/expected/${stem}.txt"

        local output
        output=$("$PARSER_EXE" "$f" 2>&1)
        local rc=$?

        local match_exp=true
        if [[ -f "$exp_file" ]]; then
            local exp_norm
            local act_norm
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

    echo ""
    echo " Parser Suite Results: $parse_passed / $parse_total passed ($parse_failed failed)"
    echo ""

    TOTAL_RUN=$((TOTAL_RUN + parse_total))
    TOTAL_PASSED=$((TOTAL_PASSED + parse_passed))
    TOTAL_FAILED=$((TOTAL_FAILED + parse_failed))
}

# ── Execute Selected Suites ──────────────────────────────────────────────────
if [[ "$SUITE" == "lexer" ]]; then
    run_lexer_suite
elif [[ "$SUITE" == "parser" ]]; then
    run_parser_suite
else
    run_lexer_suite
    run_parser_suite
fi

# ── Final Summary ────────────────────────────────────────────────────────────
echo ""
echo " Overall Test Execution Summary"
echo " Suite Executed : $SUITE"
echo " Total Tests    : $TOTAL_RUN"
echo " Passed         : $TOTAL_PASSED"
echo " Failed         : $TOTAL_FAILED"
echo ""

if [[ $TOTAL_FAILED -eq 0 ]]; then
    echo " SUCCESS: All $TOTAL_PASSED tests passed cleanly!"
    exit 0
else
    echo " FAILURE: $TOTAL_FAILED test(s) failed."
    exit 1
fi
