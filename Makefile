# ─────────────────────────────────────────────────────────────────────────────
# Makefile — THECompiler: Orchestrator
#
# Delegates to Makefile.lexer and Makefile.parser.
#
# Usage:
#   make                — build both lexer_app and syntax_analyzer
#   make lexer          — build lexer_app only
#   make parser         — build syntax_analyzer only
#   make test           — run all tests (lexer + parser)
#   make test-lexer     — run lexer tests only
#   make test-parser    — run parser tests only
#   make clean          — remove all generated files
# ─────────────────────────────────────────────────────────────────────────────

.PHONY: all lexer parser syntax test test-lexer test-parser clean

all: lexer parser

lexer:
	$(MAKE) -f Makefile.lexer all

parser:
	$(MAKE) -f Makefile.parser all

syntax: parser

test: test-lexer test-parser

test-lexer: lexer
	$(MAKE) -f Makefile.lexer test

test-parser: parser
	$(MAKE) -f Makefile.parser test

clean:
	$(MAKE) -f Makefile.lexer clean
	$(MAKE) -f Makefile.parser clean
	-rm -rf out/ 2>/dev/null || (rd /S /Q out 2>NUL) || echo Cleaned
