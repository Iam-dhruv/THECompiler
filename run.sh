#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# run.sh — Unified Cross-Platform Test Runner for THECompiler
#
# Thin wrapper that delegates to the per-component test scripts in scripts/.
#
# Usage:
#   ./run.sh                    Run ALL test cases (Lexer + Parser + IR) [Default]
#   ./run.sh --all              Run ALL test cases
#   ./run.sh --lexer, -l        Run Lexer test cases only
#   ./run.sh --parser, -p       Run Parser (Syntax) test cases only
#   ./run.sh --ir, -i           Run IR generator test cases only
#   Flags combine: ./run.sh --lexer --parser
#   ./run.sh --help, -h         Show help and usage options
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

RUN_LEXER=false
RUN_PARSER=false
RUN_IR=false
EXTRA_ARGS=()

show_help() {
    echo "THECompiler Unified Test Runner"
    echo "Usage: ./run.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  (no args)             Run ALL test suites (Lexer + Parser + IR)"
    echo "  -a, --all, all        Run ALL test suites"
    echo "  -l, --lexer, lexer    Run Lexer test suite"
    echo "  -p, --parser, parser  Run Parser (Syntax) test suite"
    echo "  --syntax, syntax      Alias for --parser"
    echo "  -i, --ir, ir          Run IR generator test suite"
    echo "  (suite flags combine, e.g. --lexer --parser)"
    echo "  -v, --verbose         Display full stdout/stderr for all tests"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Dedicated scripts (in scripts/ directory):"
    echo "  bash scripts/run_lexer_tests.sh   [--verbose] [--lexer-exe <PATH>]"
    echo "  bash scripts/run_parser_tests.sh  [--verbose] [--parser-exe <PATH>]"
    echo "  bash scripts/run_ir_tests.sh      [--verbose] [--ir-exe <PATH>]"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help|help)
            show_help
            ;;
        -l|--lexer|lexer)
            RUN_LEXER=true
            shift
            ;;
        -p|--parser|parser|--syntax|syntax)
            RUN_PARSER=true
            shift
            ;;
        -i|--ir|ir)
            RUN_IR=true
            shift
            ;;
        -a|--all|all)
            RUN_LEXER=true; RUN_PARSER=true; RUN_IR=true
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

# No suite flag selects every suite.
if [[ "$RUN_LEXER" == "false" && "$RUN_PARSER" == "false" && "$RUN_IR" == "false" ]]; then
    RUN_LEXER=true; RUN_PARSER=true; RUN_IR=true
fi

LEXER_RC=0
PARSER_RC=0
IR_RC=0

if [[ "$RUN_LEXER" == "true" ]]; then
    bash "$SCRIPT_DIR/scripts/run_lexer_tests.sh" "${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}" || LEXER_RC=$?
fi

if [[ "$RUN_PARSER" == "true" ]]; then
    bash "$SCRIPT_DIR/scripts/run_parser_tests.sh" "${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}" || PARSER_RC=$?
fi

if [[ "$RUN_IR" == "true" ]]; then
    bash "$SCRIPT_DIR/scripts/run_ir_tests.sh" "${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}" || IR_RC=$?
fi

# ── Final Summary ────────────────────────────────────────────────────────────
if [[ $LEXER_RC -ne 0 || $PARSER_RC -ne 0 || $IR_RC -ne 0 ]]; then
    echo ""
    echo " OVERALL: Some tests failed."
    exit 1
else
    echo ""
    echo " OVERALL: All selected tests passed!"
    exit 0
fi
