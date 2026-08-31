[CmdletBinding(DefaultParameterSetName = "All")]
param (
    [Parameter(ParameterSetName = "Lexer")]
    [switch]$Lexer,

    [Parameter(ParameterSetName = "Parser")]
    [switch]$Parser,

    [Parameter(ParameterSetName = "All")]
    [switch]$All,

    [Parameter()]
    [ValidateSet("all", "lexer", "parser", "syntax")]
    [string]$Suite = "all",

    [Parameter()]
    [string]$LexerExe = "",

    [Parameter()]
    [string]$ParserExe = "",

    [Parameter()]
    [switch]$Help
)

if ($Help) {
    Write-Host "THECompiler Unified PowerShell Test Runner" -ForegroundColor Cyan
    Write-Host "Usage: .\run_tests.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  (no args)             Run ALL test suites (Lexer + Parser) [Default]"
    Write-Host "  -All, -Suite all      Run ALL test suites"
    Write-Host "  -Lexer, -Suite lexer  Run Lexer test suite only"
    Write-Host "  -Parser, -Suite parser Run Parser test suite only"
    Write-Host "  -LexerExe <PATH>      Custom path to lexer binary"
    Write-Host "  -ParserExe <PATH>     Custom path to parser binary"
    Write-Host "  -Verbose              Display full output for all tests"
    Write-Host "  -Help                 Show this help message"
    exit 0
}

# Resolve target suite
$selectedSuite = "all"
if ($Lexer -or ($Suite.ToLower() -eq "lexer")) {
    $selectedSuite = "lexer"
} elseif ($Parser -or ($Suite.ToLower() -eq "parser") -or ($Suite.ToLower() -eq "syntax")) {
    $selectedSuite = "parser"
} else {
    $selectedSuite = "all"
}

$ErrorActionPreference = 'Continue'

$repo     = $PSScriptRoot
$srcDir   = Join-Path $repo 'src'
$testsDir = Join-Path $repo 'tests'
$outDir   = Join-Path $repo 'out'

New-Item -ItemType Directory -Force -Path $outDir | Out-Null

function Normalize-Text {
    param([string]$Text)
    if ($null -eq $Text) { return "" }
    return ($Text -replace "`r`n", "`n" -replace "`r", "`n").TrimEnd()
}

# ── Locate / Build Executables ───────────────────────────────────────────────
if (-not $LexerExe) {
    $LexerExe = Join-Path $repo 'lexer_app.exe'
    if (-not (Test-Path $LexerExe)) {
        $LexerExe = Join-Path $repo 'lexer_app'
    }
}

if (-not $ParserExe) {
    $ParserExe = Join-Path $repo 'syntax_analyzer.exe'
    if (-not (Test-Path $ParserExe)) {
        $ParserExe = Join-Path $repo 'parser_app.exe'
    }
    if (-not (Test-Path $ParserExe)) {
        $ParserExe = Join-Path $repo 'syntax_analyzer'
    }
}

# Auto-build lexer if needed
if (($selectedSuite -eq "lexer" -or $selectedSuite -eq "all") -and (-not (Test-Path $LexerExe))) {
    Write-Host "Lexer binary missing. Building with g++..." -ForegroundColor Yellow
    $yyc = Join-Path $srcDir 'lex.yy.c'
    if (-not (Test-Path $yyc)) {
        Push-Location $srcDir
        flex lexer.l
        Pop-Location
    }
    g++ -std=c++17 -Wno-register $yyc -o (Join-Path $repo 'lexer_app.exe')
    $LexerExe = Join-Path $repo 'lexer_app.exe'
}

# Auto-build parser if needed
if (($selectedSuite -eq "parser" -or $selectedSuite -eq "all") -and (-not (Test-Path $ParserExe))) {
    Write-Host "Parser binary missing. Building with bison/flex/g++..." -ForegroundColor Yellow
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

$totalRun = 0
$totalPassed = 0
$totalFailed = 0

# ═════════════════════════════════════════════════════════════════════════════
# 1. RUN LEXER TESTS
# ═════════════════════════════════════════════════════════════════════════════
if ($selectedSuite -eq "lexer" -or $selectedSuite -eq "all") {
    Write-Host ""
    Write-Host " [SUITE 1/2] Lexical Analyzer Tests" -ForegroundColor Cyan
    Write-Host " Executable : $LexerExe" -ForegroundColor Cyan
    Write-Host ""

    $lexPassed = 0
    $lexFailed = 0

    $lexFiles = Get-ChildItem -Path $testsDir -Include "valid_*.c", "invalid_*.c" -File -Recurse | Where-Object { $_.Name -notlike "syntax_*" } | Sort-Object Name

    foreach ($test in $lexFiles) {
        $stem = [System.IO.Path]::GetFileNameWithoutExtension($test.Name)
        $expFile = Join-Path $testsDir "expected\$stem.txt"
        $tsFile = Join-Path $outDir "token_stream_$stem.txt"

        $output = & $LexerExe $test.FullName 2>&1
        $rc = $LASTEXITCODE

        $pass = $false
        if (Test-Path $expFile) {
            $expected = Normalize-Text (Get-Content -Path $expFile -Raw -ErrorAction SilentlyContinue)
            $actual = Normalize-Text (Get-Content -Path $tsFile -Raw -ErrorAction SilentlyContinue)
            if ($expected -eq $actual) {
                $pass = $true
            }
        } else {
            if ($test.Name -like "invalid_*") {
                if ($rc -ne 0) { $pass = $true }
            } else {
                if ($rc -eq 0) { $pass = $true }
            }
        }

        if ($pass) {
            $lexPassed++
            Write-Host "[PASS] $($test.Name)" -ForegroundColor Green
        } else {
            $lexFailed++
            Write-Host "[FAIL] $($test.Name) (Exit Code: $rc)" -ForegroundColor Red
        }
    }

    $lexTotal = $lexFiles.Count
    Write-Host ""
    Write-Host " Lexer Suite Results: $lexPassed / $lexTotal passed ($lexFailed failed)" -ForegroundColor Cyan
    Write-Host ""

    $totalRun += $lexTotal
    $totalPassed += $lexPassed
    $totalFailed += $lexFailed
}

# ═════════════════════════════════════════════════════════════════════════════
# 2. RUN PARSER TESTS
# ═════════════════════════════════════════════════════════════════════════════
if ($selectedSuite -eq "parser" -or $selectedSuite -eq "all") {
    Write-Host ""
    Write-Host " [SUITE 2/2] Syntax Analyzer (Parser) Tests" -ForegroundColor Cyan
    Write-Host " Executable : $ParserExe" -ForegroundColor Cyan
    Write-Host ""

    $parsePassed = 0
    $parseFailed = 0

    $validSyntaxTests = Get-ChildItem -Path $testsDir -Filter "syntax_valid_*.c" | Sort-Object Name
    $invalidSyntaxTests = Get-ChildItem -Path $testsDir -Filter "syntax_invalid_*.c" | Sort-Object Name

    Write-Host "--- Running Valid Syntax Tests (Exit 0 & Token Table Expected) ---" -ForegroundColor Yellow
    foreach ($test in $validSyntaxTests) {
        $stem = [System.IO.Path]::GetFileNameWithoutExtension($test.Name)
        $expFile = Join-Path $testsDir "expected\$stem.txt"
        $relPath = "tests/$($test.Name)"

        $output = & $ParserExe $relPath 2>&1
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
        }
    }

    Write-Host ""
    Write-Host "--- Running Invalid Syntax Tests (Syntax Error Expected) ---" -ForegroundColor Yellow
    foreach ($test in $invalidSyntaxTests) {
        $stem = [System.IO.Path]::GetFileNameWithoutExtension($test.Name)
        $expFile = Join-Path $testsDir "expected\$stem.txt"
        $relPath = "tests/$($test.Name)"

        $output = & $ParserExe $relPath 2>&1
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
        }
    }

    $parseTotal = $validSyntaxTests.Count + $invalidSyntaxTests.Count
    Write-Host ""
    Write-Host " Parser Suite Results: $parsePassed / $parseTotal passed ($parseFailed failed)" -ForegroundColor Cyan
    Write-Host ""

    $totalRun += $parseTotal
    $totalPassed += $parsePassed
    $totalFailed += $parseFailed
}

# ── Overall Summary ──────────────────────────────────────────────────────────
Write-Host ""
Write-Host " Overall Test Execution Summary" -ForegroundColor Cyan
Write-Host " Suite Executed : $selectedSuite" -ForegroundColor Cyan
Write-Host " Total Tests    : $totalRun" -ForegroundColor Cyan
Write-Host " Passed         : $totalPassed" -ForegroundColor Green
Write-Host " Failed         : $totalFailed" -ForegroundColor $(if ($totalFailed -eq 0) { "Green" } else { "Red" })
Write-Host ""

if ($totalFailed -eq 0) {
    Write-Host " SUCCESS: All $totalPassed tests passed cleanly!" -ForegroundColor Green
    exit 0
} else {
    Write-Host " FAILURE: $totalFailed test(s) failed." -ForegroundColor Red
    exit 1
}
