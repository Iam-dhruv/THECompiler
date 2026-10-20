#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# run_ir_tests.sh — IR Generator Test Runner for THECompiler
#
# Valid tests:   tests/ir/valid/*.c must exit 0 and produce IR identical to
#                tests/ir/expected/valid/<name>.ir (hand-written).
# Invalid tests: tests/ir/invalid/*.c must exit non-zero, write no IR file,
#                and print exactly tests/ir/expected/invalid/<name>.txt.
#
# Usage:
#   bash scripts/run_ir_tests.sh
#   bash scripts/run_ir_tests.sh --verbose
#   bash scripts/run_ir_tests.sh --ir-exe ./path/to/ir_generator
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

TESTS_DIR="tests/ir"
IR_EXE=""
VERBOSE=false

# ── Parse Arguments ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            echo "IR Generator Test Runner"
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "  --ir-exe <PATH>      Path to ir_generator executable"
            echo "  -v, --verbose        Display full output for all tests"
            echo "  -h, --help           Show this help message"
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --ir-exe)
            IR_EXE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# ── Auto-Detect / Build Executable ──────────────────────────────────────────
if [[ -z "$IR_EXE" ]]; then
    make -f Makefile.ir all >/dev/null 2>&1 || true
    for p in "./ir_generator" "./ir_generator.exe"; do
        if [[ -f "$p" ]]; then
            IR_EXE="$p"
            break
        fi
    done
fi

if [[ -z "$IR_EXE" || ! -f "$IR_EXE" ]]; then
    echo "Error: IR generator executable not found. Run 'make ir' first."
    exit 1
fi

OUT_DIR="$(mktemp -d)"
trap 'rm -rf "$OUT_DIR"' EXIT

# ── Text Normalizer ─────────────────────────────────────────────────────────
normalize_text() {
    sed 's/\r$//' | sed -e :a -e '/^\n*$/{$d;N;};/\n$/ba'
}

echo ""
echo " ╔═══════════════════════════════════════════╗"
echo " ║        IR Generator (3AC) Test Suite      ║"
echo " ╚═══════════════════════════════════════════╝"
echo " Executable : $IR_EXE"
echo ""

passed=0
failed=0
total=0

shopt -s nullglob

# ── Valid Programs ───────────────────────────────────────────────────────────
echo "--- Running Valid IR Tests (Exit 0 & IR Must Match Expected) ---"
for f in $TESTS_DIR/valid/*.c; do
    total=$((total + 1))
    name="$(basename "$f")"
    stem="${name%.c}"
    exp_file="$TESTS_DIR/expected/valid/${stem}.ir"
    out_file="$OUT_DIR/${stem}.ir"

    output=$("$IR_EXE" "$f" -o "$out_file" 2>&1)
    rc=$?

    status="ok"
    if [[ $rc -ne 0 ]]; then
        status="exit code $rc"
    elif [[ ! -f "$exp_file" ]]; then
        status="missing expected file $exp_file"
    elif [[ "$(normalize_text < "$exp_file")" != "$(normalize_text < "$out_file")" ]]; then
        status="IR differs from expected"
    fi

    if [[ "$status" == "ok" ]]; then
        passed=$((passed + 1))
        echo "[PASS] $name"
        if [[ "$VERBOSE" == "true" ]]; then cat "$out_file"; fi
    else
        failed=$((failed + 1))
        echo "[FAIL] $name ($status)"
        echo "$output"
        if [[ -f "$out_file" && -f "$exp_file" ]]; then
            diff <(normalize_text < "$exp_file") <(normalize_text < "$out_file") | sed 's/^/    /'
        fi
    fi
done

# ── Invalid Programs ─────────────────────────────────────────────────────────
echo ""
echo "--- Running Invalid IR Tests (Semantic Error Expected, No IR File) ---"
for f in $TESTS_DIR/invalid/*.c; do
    total=$((total + 1))
    name="$(basename "$f")"
    stem="${name%.c}"
    exp_file="$TESTS_DIR/expected/invalid/${stem}.txt"
    out_file="$OUT_DIR/${stem}.ir"

    output=$("$IR_EXE" "$f" -o "$out_file" 2>&1)
    rc=$?

    status="ok"
    if [[ $rc -eq 0 ]]; then
        status="expected failure, got exit 0"
    elif [[ -f "$out_file" ]]; then
        status="IR file written despite errors"
    elif [[ ! -f "$exp_file" ]]; then
        status="missing expected file $exp_file"
    elif [[ "$(normalize_text < "$exp_file")" != "$(echo "$output" | normalize_text)" ]]; then
        status="error output differs from expected"
    fi

    if [[ "$status" == "ok" ]]; then
        passed=$((passed + 1))
        echo "[PASS] $name (correctly rejected, exit code: $rc)"
        if [[ "$VERBOSE" == "true" ]]; then echo "$output"; fi
    else
        failed=$((failed + 1))
        echo "[FAIL] $name ($status)"
        echo "$output"
        if [[ -f "$exp_file" ]]; then
            diff <(normalize_text < "$exp_file") <(echo "$output" | normalize_text) | sed 's/^/    /'
        fi
    fi
done

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo " ┌─────────────────────────────────────────┐"
echo " │ IR Test Results: $passed / $total passed ($failed failed)"
echo " └─────────────────────────────────────────┘"
echo ""

if [[ $failed -eq 0 ]]; then
    echo " SUCCESS: All $passed IR tests passed!"
    exit 0
else
    echo " FAILURE: $failed IR test(s) failed."
    exit 1
fi
