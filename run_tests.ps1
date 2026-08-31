# ─────────────────────────────────────────────────────────────────────────────
# run_tests.ps1 — Unified PowerShell Test Runner for THECompiler
#
# Thin wrapper that delegates to per-component test scripts in scripts\.
#
# Usage:
#   .\run_tests.ps1               Run ALL test suites (Lexer + Parser)
#   .\run_tests.ps1 -Lexer        Run Lexer test suite only
#   .\run_tests.ps1 -Parser       Run Parser test suite only
#   .\run_tests.ps1 -Help         Show help
# ─────────────────────────────────────────────────────────────────────────────

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
    Write-Host ""
    Write-Host "Dedicated scripts (in scripts\ directory):"
    Write-Host "  .\scripts\run_lexer_tests.ps1  [-LexerExe <PATH>] [-Verbose]"
    Write-Host "  .\scripts\run_parser_tests.ps1 [-ParserExe <PATH>] [-Verbose]"
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

$repo = $PSScriptRoot
$lexerScript = Join-Path $repo 'scripts\run_lexer_tests.ps1'
$parserScript = Join-Path $repo 'scripts\run_parser_tests.ps1'

$lexerFailed = $false
$parserFailed = $false

if ($selectedSuite -eq "lexer" -or $selectedSuite -eq "all") {
    $lexerArgs = @()
    if ($LexerExe) { $lexerArgs += @("-LexerExe", $LexerExe) }
    if ($VerbosePreference -eq 'Continue') { $lexerArgs += "-Verbose" }
    & $lexerScript @lexerArgs
    if ($LASTEXITCODE -ne 0) { $lexerFailed = $true }
}

if ($selectedSuite -eq "parser" -or $selectedSuite -eq "all") {
    $parserArgs = @()
    if ($ParserExe) { $parserArgs += @("-ParserExe", $ParserExe) }
    if ($VerbosePreference -eq 'Continue') { $parserArgs += "-Verbose" }
    & $parserScript @parserArgs
    if ($LASTEXITCODE -ne 0) { $parserFailed = $true }
}

# ── Overall Summary ──────────────────────────────────────────────────────────
Write-Host ""
if ($lexerFailed -or $parserFailed) {
    Write-Host " OVERALL: Some tests failed." -ForegroundColor Red
    exit 1
} else {
    Write-Host " OVERALL: All selected tests passed!" -ForegroundColor Green
    exit 0
}
