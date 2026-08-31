#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# run.sh — Unified Cross-Platform Test Runner for THECompiler
#
# Thin wrapper that delegates to the per-component test scripts in scripts/.
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

SUITE="all"
EXTRA_ARGS=()

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
    echo "  -v, --verbose         Display full stdout/stderr for all tests"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Dedicated scripts (in scripts/ directory):"
    echo "  bash scripts/run_lexer_tests.sh   [--verbose] [--lexer-exe <PATH>]"
    echo "  bash scripts/run_parser_tests.sh  [--verbose] [--parser-exe <PATH>]"
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
            EXTRA_ARGS+=("--verbose")
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Run './run.sh --help' for available options."
            exit 1
            ;;
    esac
done

LEXER_RC=0
PARSER_RC=0

if [[ "$SUITE" == "lexer" || "$SUITE" == "all" ]]; then
    bash "$SCRIPT_DIR/scripts/run_lexer_tests.sh" "${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}" || LEXER_RC=$?
fi

if [[ "$SUITE" == "parser" || "$SUITE" == "all" ]]; then
    bash "$SCRIPT_DIR/scripts/run_parser_tests.sh" "${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}" || PARSER_RC=$?
fi

# ── Final Summary ────────────────────────────────────────────────────────────
if [[ $LEXER_RC -ne 0 || $PARSER_RC -ne 0 ]]; then
    echo ""
    echo " OVERALL: Some tests failed."
    exit 1
else
    echo ""
    echo " OVERALL: All selected tests passed!"
    exit 0
fi
