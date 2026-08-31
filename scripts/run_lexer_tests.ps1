# ─────────────────────────────────────────────────────────────────────────────
# run_lexer_tests.ps1 — Lexer-Only PowerShell Test Runner for THECompiler
#
# Usage:
#   .\scripts\run_lexer_tests.ps1
#   .\scripts\run_lexer_tests.ps1 -Verbose
#   .\scripts\run_lexer_tests.ps1 -LexerExe .\path\to\lexer.exe
# ─────────────────────────────────────────────────────────────────────────────

param (
    [string]$LexerExe = "",
    [switch]$Help
)

if ($Help) {
    Write-Host "THECompiler Lexer Test Runner (PowerShell)" -ForegroundColor Cyan
    Write-Host "Usage: .\scripts\run_lexer_tests.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "  -LexerExe <PATH>  Custom path to lexer binary"
    Write-Host "  -Verbose          Display full output for all tests"
    Write-Host "  -Help             Show this help message"
    exit 0
}

$ErrorActionPreference = 'Continue'

$repo     = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$testsDir = Join-Path $repo 'tests\lexer'
$outDir   = Join-Path $repo 'out'

New-Item -ItemType Directory -Force -Path $outDir | Out-Null

function Normalize-Text {
    param([string]$Text)
    if ($null -eq $Text) { return "" }
    return ($Text -replace "`r`n", "`n" -replace "`r", "`n").TrimEnd()
}

# ── Locate / Build Executable ───────────────────────────────────────────────
if (-not $LexerExe) {
    $LexerExe = Join-Path $repo 'lexer_app.exe'
    if (-not (Test-Path $LexerExe)) {
        $LexerExe = Join-Path $repo 'lexer_app'
    }
}

if (-not (Test-Path $LexerExe)) {
    Write-Host "Lexer binary missing. Building with make..." -ForegroundColor Yellow
    Push-Location $repo
    $srcDir = Join-Path $repo 'src\lexer'
    $yyc = Join-Path $srcDir 'lex.yy.c'
    if (-not (Test-Path $yyc)) {
        Push-Location $srcDir
        flex lexer.l
        Pop-Location
    }
    g++ -std=c++17 -Wno-register $yyc -o (Join-Path $repo 'lexer_app.exe')
    $LexerExe = Join-Path $repo 'lexer_app.exe'
    Pop-Location
}

# ═════════════════════════════════════════════════════════════════════════════
# RUN LEXER TESTS
# ═════════════════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host " Lexical Analyzer Test Suite" -ForegroundColor Cyan
Write-Host " Executable : $LexerExe" -ForegroundColor Cyan
Write-Host ""

$lexPassed = 0
$lexFailed = 0

# ── Valid Tests ──────────────────────────────────────────────────────────────
Write-Host "--- Running Valid Lexer Tests ---" -ForegroundColor Yellow
$validFiles = Get-ChildItem -Path (Join-Path $testsDir 'valid') -Filter "*.c" -File | Sort-Object Name

foreach ($test in $validFiles) {
    $stem = [System.IO.Path]::GetFileNameWithoutExtension($test.Name)
    $expFile = Join-Path $testsDir "expected\valid\$stem.txt"
    $tsFile = Join-Path $outDir "token_stream_$stem.txt"

    $output = & $LexerExe $test.FullName 2>&1
    $rc = $LASTEXITCODE

    $pass = $false
    if ((Test-Path $expFile) -and (Test-Path $tsFile)) {
        $expected = Normalize-Text (Get-Content -Path $expFile -Raw -ErrorAction SilentlyContinue)
        $actual = Normalize-Text (Get-Content -Path $tsFile -Raw -ErrorAction SilentlyContinue)
        if ($expected -eq $actual) {
            $pass = $true
        }
    } else {
        if ($rc -eq 0) { $pass = $true }
    }

    if ($pass) {
        $lexPassed++
        Write-Host "[PASS] $($test.Name)" -ForegroundColor Green
    } else {
        $lexFailed++
        Write-Host "[FAIL] $($test.Name) (Exit Code: $rc)" -ForegroundColor Red
        if ($VerbosePreference -eq 'Continue') { Write-Host ($output -join "`n") }
    }
}

# ── Invalid Tests ────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "--- Running Invalid Lexer Tests ---" -ForegroundColor Yellow
$invalidFiles = Get-ChildItem -Path (Join-Path $testsDir 'invalid') -Filter "*.c" -File | Sort-Object Name

foreach ($test in $invalidFiles) {
    $stem = [System.IO.Path]::GetFileNameWithoutExtension($test.Name)
    $expFile = Join-Path $testsDir "expected\invalid\$stem.txt"
    $tsFile = Join-Path $outDir "token_stream_$stem.txt"

    $output = & $LexerExe $test.FullName 2>&1
    $rc = $LASTEXITCODE

    $pass = $false
    if ((Test-Path $expFile) -and (Test-Path $tsFile)) {
        $expected = Normalize-Text (Get-Content -Path $expFile -Raw -ErrorAction SilentlyContinue)
        $actual = Normalize-Text (Get-Content -Path $tsFile -Raw -ErrorAction SilentlyContinue)
        if ($expected -eq $actual) {
            $pass = $true
        }
    } else {
        if ($rc -ne 0) { $pass = $true }
    }

    if ($pass) {
        $lexPassed++
        Write-Host "[PASS] $($test.Name)" -ForegroundColor Green
    } else {
        $lexFailed++
        Write-Host "[FAIL] $($test.Name) (Exit Code: $rc)" -ForegroundColor Red
        if ($VerbosePreference -eq 'Continue') { Write-Host ($output -join "`n") }
    }
}

# ── Summary ──────────────────────────────────────────────────────────────────
$lexTotal = $validFiles.Count + $invalidFiles.Count
Write-Host ""
Write-Host " Lexer Test Results: $lexPassed / $lexTotal passed ($lexFailed failed)" -ForegroundColor Cyan
Write-Host ""

if ($lexFailed -eq 0) {
    Write-Host " SUCCESS: All $lexPassed lexer tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host " FAILURE: $lexFailed lexer test(s) failed." -ForegroundColor Red
    exit 1
}
