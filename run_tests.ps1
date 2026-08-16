$ErrorActionPreference = 'Continue'

$repo = $PSScriptRoot
$srcDir = Join-Path $repo 'src'
$testsDir = Join-Path $repo 'tests'

Set-Location $srcDir

g++ -std=c++17 -Wno-register lex.yy.c -o lexer_app.exe

$validTests = @(
    @{ File = 'valid_basic.c'; Expected = Join-Path $testsDir 'expected\valid_basic.txt' },
    @{ File = 'valid_keywords_ops.c'; Expected = Join-Path $testsDir 'expected\valid_keywords_ops.txt' },
    @{ File = 'valid_literals.c'; Expected = Join-Path $testsDir 'expected\valid_literals.txt' },
    @{ File = 'valid_comments.c'; Expected = Join-Path $testsDir 'expected\valid_comments.txt' },
    @{ File = 'valid_numeric_edges.c'; Expected = Join-Path $testsDir 'expected\valid_numeric_edges.txt' },
    @{ File = 'valid_float_dot_forms.c'; Expected = Join-Path $testsDir 'expected\valid_float_dot_forms.txt' }
)

$invalidTests = @(
    @{ File = 'invalid_bad_char.c'; ExpectedContains = 'Error: unexpected character' },
    @{ File = 'invalid_octal_literal.c'; ExpectedContains = 'Error: Invalid Octal literal' },
    @{ File = 'invalid_malformed_scientific.c'; ExpectedContains = 'Error: malformed scientific notation' },
    @{ File = 'invalid_malformed_float.c'; ExpectedContains = 'Error: unexpected character' },
    @{ File = 'invalid_unterminated_string.c'; ExpectedContains = 'Error: unterminated string literal starting at line 2' },
    @{ File = 'invalid_unterminated_comment.c'; ExpectedContains = 'Error: unterminated comment' }
)

foreach ($test in $validTests) {
    $input = Join-Path $testsDir $test.File
    $expected = (Get-Content $test.Expected -Raw).TrimEnd()

    Write-Host "Running valid test: $($test.File)"
    $actual = (& .\lexer_app.exe $input 2>&1 | Out-String).TrimEnd()

    if ($LASTEXITCODE -ne 0 -or $actual -notmatch [regex]::Escape($expected)) {
        Write-Host "VALID TEST FAILED: $($test.File)"
        Write-Host "--- actual ---"
        Write-Host $actual
        Write-Host "--- expected ---"
        Write-Host $expected
        exit 1
    }
}

foreach ($test in $invalidTests) {
    $input = Join-Path $testsDir $test.File

    Write-Host "Running invalid test: $($test.File)"
    $actual = (& cmd /c "lexer_app.exe ..\tests\$($test.File) 2>&1" | Out-String).TrimEnd()

    if ($actual -notmatch [regex]::Escape($test.ExpectedContains)) {
        Write-Host "INVALID TEST FAILED: $($test.File)"
        Write-Host "--- actual ---"
        Write-Host $actual
        Write-Host "--- expected contains ---"
        Write-Host $test.ExpectedContains
        exit 1
    }
}

Write-Host "All lexer tests passed."
