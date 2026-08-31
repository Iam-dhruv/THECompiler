# ─────────────────────────────────────────────────────────────────────────────
# run_parser_tests.ps1 — Parser-Only PowerShell Test Runner for THECompiler
#
# Usage:
#   .\scripts\run_parser_tests.ps1
#   .\scripts\run_parser_tests.ps1 -Verbose
#   .\scripts\run_parser_tests.ps1 -ParserExe .\path\to\parser.exe
# ─────────────────────────────────────────────────────────────────────────────

param (
    [string]$ParserExe = "",
    [switch]$Help
)

if ($Help) {
    Write-Host "THECompiler Parser Test Runner (PowerShell)" -ForegroundColor Cyan
    Write-Host "Usage: .\scripts\run_parser_tests.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "  -ParserExe <PATH>  Custom path to parser binary"
    Write-Host "  -Verbose           Display full output for all tests"
    Write-Host "  -Help              Show this help message"
    exit 0
}

$ErrorActionPreference = 'Continue'

$repo     = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$testsDir = Join-Path $repo 'tests\parser'

function Normalize-Text {
    param([string]$Text)
    if ($null -eq $Text) { return "" }
    return ($Text -replace "`r`n", "`n" -replace "`r", "`n").TrimEnd()
}

# ── Locate / Build Executable ───────────────────────────────────────────────
if (-not $ParserExe) {
    $ParserExe = Join-Path $repo 'syntax_analyzer.exe'
    if (-not (Test-Path $ParserExe)) {
        $ParserExe = Join-Path $repo 'parser_app.exe'
    }
    if (-not (Test-Path $ParserExe)) {
        $ParserExe = Join-Path $repo 'syntax_analyzer'
    }
}

if (-not (Test-Path $ParserExe)) {
    Write-Host "Parser binary missing. Building with bison/flex/g++..." -ForegroundColor Yellow
    $srcDir = Join-Path $repo 'src\parser'
    Push-Location $srcDir
    $env:BISON_PKGDATADIR = 'C:/PROGRA~2/GnuWin32/share/bison'
    $env:M4 = 'C:/PROGRA~2/GnuWin32/bin/m4.exe'
    bison -d -o parser.tab.c parser.y
    flex parser_lexer.l
    if (Test-Path "lex.yy.c") {
        Move-Item -Force "lex.yy.c" "lex.yy.parser.c"
    }
    Pop-Location
    g++ -std=c++17 -Wno-register (Join-Path $srcDir 'parser.tab.c') (Join-Path $srcDir 'lex.yy.parser.c') -o (Join-Path $repo 'syntax_analyzer.exe')
    $ParserExe = Join-Path $repo 'syntax_analyzer.exe'
}

# ═════════════════════════════════════════════════════════════════════════════
# RUN PARSER TESTS
# ═════════════════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host " Syntax Analyzer (Parser) Test Suite" -ForegroundColor Cyan
Write-Host " Executable : $ParserExe" -ForegroundColor Cyan
Write-Host ""

$parsePassed = 0
$parseFailed = 0

# ── Valid Syntax Tests ───────────────────────────────────────────────────────
Write-Host "--- Running Valid Syntax Tests (Exit 0 & Token Table Expected) ---" -ForegroundColor Yellow
$validTests = Get-ChildItem -Path (Join-Path $testsDir 'valid') -Filter "*.c" -File | Sort-Object Name

foreach ($test in $validTests) {
    $stem = [System.IO.Path]::GetFileNameWithoutExtension($test.Name)
    $expFile = Join-Path $testsDir "expected\valid\$stem.txt"

    $output = & $ParserExe $test.FullName 2>&1
    $rc = $LASTEXITCODE

    $matchExp = $true
    if (Test-Path $expFile) {
        $expected = Normalize-Text (Get-Content -Path $expFile -Raw -ErrorAction SilentlyContinue)
        $actual = Normalize-Text ($output -join "`n")
        if ($expected -ne $actual) {
            $matchExp = $false
        }
    }

    if ($rc -eq 0 -and $matchExp) {
        $parsePassed++
        Write-Host "[PASS] $($test.Name)" -ForegroundColor Green
    } else {
        $parseFailed++
        Write-Host "[FAIL] $($test.Name) (Exit Code: $rc, Matched Expected: $matchExp)" -ForegroundColor Red
        if ($VerbosePreference -eq 'Continue') { Write-Host ($output -join "`n") }
    }
}

# ── Invalid Syntax Tests ────────────────────────────────────────────────────
Write-Host ""
Write-Host "--- Running Invalid Syntax Tests (Syntax Error Expected) ---" -ForegroundColor Yellow
$invalidTests = Get-ChildItem -Path (Join-Path $testsDir 'invalid') -Filter "*.c" -File | Sort-Object Name

foreach ($test in $invalidTests) {
    $stem = [System.IO.Path]::GetFileNameWithoutExtension($test.Name)
    $expFile = Join-Path $testsDir "expected\invalid\$stem.txt"

    $output = & $ParserExe $test.FullName 2>&1
    $rc = $LASTEXITCODE

    $matchExp = $true
    if (Test-Path $expFile) {
        $expected = Normalize-Text (Get-Content -Path $expFile -Raw -ErrorAction SilentlyContinue)
        $actual = Normalize-Text ($output -join "`n")
        if ($expected -ne $actual) {
            $matchExp = $false
        }
    }

    if ($rc -ne 0 -and $matchExp) {
        $parsePassed++
        Write-Host "[PASS] $($test.Name) (correctly reported syntax error, exit code: $rc)" -ForegroundColor Green
    } else {
        $parseFailed++
        Write-Host "[FAIL] $($test.Name) (Exit Code: $rc, Matched Expected: $matchExp)" -ForegroundColor Red
        if ($VerbosePreference -eq 'Continue') { Write-Host ($output -join "`n") }
    }
}

# ── Summary ──────────────────────────────────────────────────────────────────
$parseTotal = $validTests.Count + $invalidTests.Count
Write-Host ""
Write-Host " Parser Test Results: $parsePassed / $parseTotal passed ($parseFailed failed)" -ForegroundColor Cyan
Write-Host ""

if ($parseFailed -eq 0) {
    Write-Host " SUCCESS: All $parsePassed parser tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host " FAILURE: $parseFailed parser test(s) failed." -ForegroundColor Red
    exit 1
}
