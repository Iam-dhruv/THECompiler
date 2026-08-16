$ErrorActionPreference = 'Continue'

$repo     = $PSScriptRoot
$srcDir   = Join-Path $repo 'src'
$testsDir = Join-Path $repo 'tests'
$outDir   = Join-Path $repo 'out'
$lexer    = Join-Path $repo 'lexer_app.exe'   # built at project root by Makefile

# ── Helpers ───────────────────────────────────────────────────────────────────
function Normalize-Text {
    param([string]$Text)
    if ($null -eq $Text) { return "" }
    return ($Text -replace "`r`n", "`n" -replace "`r", "`n").TrimEnd()
}

function Stem([string]$FileName) {
    return [System.IO.Path]::GetFileNameWithoutExtension($FileName)
}

# ── Build ─────────────────────────────────────────────────────────────────────
# Ensure lex.yy.c exists; rebuild with flex if missing.
$yyc = Join-Path $srcDir 'lex.yy.c'
if (-not (Test-Path $yyc)) {
    if (Get-Command flex -ErrorAction SilentlyContinue) {
        Push-Location $srcDir
        flex lexer.l
        Pop-Location
    } else {
        Write-Error "flex is not installed and lex.yy.c is missing. Aborting."
        exit 1
    }
}
# Compile → lexer_app.exe at project root (not inside src/).
# Build the binary if it doesn't exist yet.
# Re-run `flex` + `g++` only when necessary to keep the script fast,
# but always ensures a working binary is present before running any tests.
if (-not (Test-Path $lexer)) {
    Write-Host "Binary not found — building lexer..."
    $yyc = Join-Path $srcDir 'lex.yy.c'
    if (-not (Test-Path $yyc)) {
        if (Get-Command flex -ErrorAction SilentlyContinue) {
            Push-Location $srcDir; flex lexer.l; Pop-Location
        } else {
            Write-Error "flex is not installed and lex.yy.c is missing. Aborting."
            exit 1
        }
    }
    g++ -std=c++17 -Wno-register $yyc -o $lexer
    if ($LASTEXITCODE -ne 0) { Write-Error "Compilation failed. Aborting."; exit 1 }
    Write-Host "Build complete: $lexer"
} else {
    Write-Host "Using existing binary: $lexer"
}

# ── Ensure out/ directory exists ─────────────────────────────────────────────
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

# ── Valid tests ───────────────────────────────────────────────────────────────
# Each valid test lexes cleanly (exit 0).  We compare the token_stream output
# file against a stored expected file in tests/expected/.
$validTests = @(
    # ── Original (improved inputs) ──
    @{ File = 'valid_basic.c';           Note = 'basic program: int/float/char/string/return' },
    @{ File = 'valid_keywords_ops.c';    Note = 'all compound-assign + relational + logical ops' },
    @{ File = 'valid_literals.c';        Note = 'all int forms, float forms, char escapes, strings' },
    @{ File = 'valid_comments.c';        Note = 'inline block, leading block, multi-line, trailing line comments' },
    @{ File = 'valid_numeric_edges.c';   Note = 'zero, dec, hex, floats, exponents' },
    @{ File = 'valid_float_dot_forms.c'; Note = 'leading-dot, trailing-dot, and mixed float forms' },
    # ── New: keyword / operator coverage ──
    @{ File = 'valid_control_flow.c';    Note = 'if/else/for/while/do/switch/case/default/break/continue/goto/return' },
    @{ File = 'valid_type_keywords.c';   Note = 'int/char/float/double/void/static/struct/typedef/enum/union/class/access/this/new/delete/virtual/friend' },
    @{ File = 'valid_all_operators.c';   Note = 'arithmetic/bitwise/shift/incr/relational/logical' },
    @{ File = 'valid_assign_ops.c';      Note = 'all assignment and compound-assignment operators' },
    @{ File = 'valid_punctuation.c';     Note = 'dot/arrow/brackets/parens/braces/ternary/semicolon/comma' },
    # ── New: literal coverage ──
    @{ File = 'valid_int_literals.c';    Note = 'zero, single-digit, multi-digit, all hex forms' },
    @{ File = 'valid_float_literals.c';  Note = 'all float literal forms' },
    @{ File = 'valid_char_literals.c';   Note = 'all valid char literals incl. expanded escapes \r\0\a\b\f\v\"' },
    @{ File = 'valid_strings.c';         Note = 'empty, plain, escaped strings' },
    @{ File = 'valid_identifiers.c';     Note = 'all legal identifier forms' },
    @{ File = 'valid_comments_all.c';    Note = 'block/inline-block/single-line/trailing/multi-line' },
    @{ File = 'valid_combined.c';        Note = 'real-world: keywords + ops + string/char + control flow' }
)

# ── Invalid tests ─────────────────────────────────────────────────────────────
# Each invalid test exits non-zero.  We check that the error_log file contains
# the expected substring.
$invalidTests = @(
    # ── Original ──
    @{ File = 'invalid_bad_char.c';              ExpectedContains = 'Error: unexpected character';                   Note = 'bad chars: @, $, backtick' },
    @{ File = 'invalid_octal_literal.c';         ExpectedContains = 'Error: Invalid Octal literal';                 Note = 'leading-zero multi-digit literals' },
    @{ File = 'invalid_malformed_scientific.c';  ExpectedContains = 'Error: malformed scientific notation';         Note = 'missing digits after e/E' },
    @{ File = 'invalid_unterminated_string.c';   ExpectedContains = 'Error: unterminated string literal starting at line 2'; Note = 'unterminated string — start line reported' },
    @{ File = 'invalid_unterminated_comment.c';  ExpectedContains = 'Error: unterminated comment starting at line 2'; Note = 'unterminated comment — correct start line' },
    # ── New: comment errors ──
    @{ File = 'invalid_comment_eof.c';            ExpectedContains = 'Error: unterminated comment starting at line 1'; Note = 'comment opens at line 1, EOF hit' },
    @{ File = 'invalid_comment_multiline_eof.c';  ExpectedContains = 'Error: unterminated comment starting at line 2'; Note = 'multi-line: /* at line 2' },
    # ── New: char literal errors ──
    @{ File = 'invalid_char_multichar.c';         ExpectedContains = 'Error: multi-character char literal';           Note = "Bug-4: 'ab' must error" },
    @{ File = 'invalid_char_unterminated.c';      ExpectedContains = 'Error: unterminated char literal';              Note = 'char literal terminated by newline' },
    # ── New: string errors ──
    @{ File = 'invalid_string_newline.c';         ExpectedContains = 'Error: unterminated string literal starting at line 1'; Note = 'newline inside string returns T_ERROR' },
    @{ File = 'invalid_string_eof.c';             ExpectedContains = 'Error: unterminated string literal starting at line 1'; Note = 'string hits EOF without closing quote' }
)

$passed = 0; $failed = 0

# ── Run valid tests ───────────────────────────────────────────────────────────
foreach ($test in $validTests) {
    $input   = Join-Path $testsDir $test.File
    $stem    = Stem $test.File
    $expFile = Join-Path $testsDir "expected\$stem.txt"
    $tsFile  = Join-Path $outDir   "token_stream_$stem.txt"

    # Run lexer (output goes to out/ automatically)
    & $lexer $input | Out-Null
    $exitOk = ($LASTEXITCODE -eq 0)

    $expected = Normalize-Text (Get-Content -Path $expFile -Raw -ErrorAction SilentlyContinue)
    $actual   = Normalize-Text (Get-Content -Path $tsFile  -Raw -ErrorAction SilentlyContinue)
    $ok       = $exitOk -and ($actual -eq $expected)

    if ($ok) {
        $passed++
        Write-Host "[PASS] $($test.File)"
    } else {
        $failed++
        Write-Host "[FAIL] $($test.File)  # $($test.Note)"
        if (-not $exitOk) { Write-Host "  lexer exited with errors" }
        if ($actual -ne $expected) {
            Write-Host "  actual   ($tsFile):"
            Write-Host "  $actual"
            Write-Host "  expected ($expFile):"
            Write-Host "  $expected"
        }
    }
}

# ── Run invalid tests ─────────────────────────────────────────────────────────
foreach ($test in $invalidTests) {
    $input   = Join-Path $testsDir $test.File
    $stem    = Stem $test.File
    $errFile = Join-Path $outDir "error_log_$stem.txt"

    # Run lexer
    & $lexer $input 2>&1 | Out-Null
    $exitNonZero = ($LASTEXITCODE -ne 0)

    $errContent = Normalize-Text (Get-Content -Path $errFile -Raw -ErrorAction SilentlyContinue)
    $ok = $exitNonZero -and $errContent.Contains($test.ExpectedContains)

    if ($ok) {
        $passed++
        Write-Host "[PASS] $($test.File)"
    } else {
        $failed++
        Write-Host "[FAIL] $($test.File)  # $($test.Note)"
        if (-not $exitNonZero) { Write-Host "  lexer exited 0 — expected non-zero for error case" }
        if (-not $errContent.Contains($test.ExpectedContains)) {
            Write-Host "  error_log ($errFile):"
            Write-Host "  $errContent"
            Write-Host "  expected to contain:"
            Write-Host "  $($test.ExpectedContains)"
        }
    }
}

# ── Summary ───────────────────────────────────────────────────────────────────
$total = $validTests.Count + $invalidTests.Count
Write-Host ""
Write-Host "Summary: $passed passed, $failed failed, $total total."
Write-Host "All output files in: $outDir"

if ($failed -gt 0) { exit 1 }
