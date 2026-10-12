# Makefile — THECompiler: Orchestrator
#
# Delegates to Makefile.lexer, Makefile.parser, and Makefile.ir.
#
# Usage:
#   make                — build all phases (lexer, parser, ir)
#   make lexer          — build lexer_app only
#   make parser         — build syntax_analyzer only
#   make ir             — build ir_generator only
#   make test           — run all tests (lexer + parser)
#   make test-lexer     — run lexer tests only
#   make test-parser    — run parser tests only
#   make clean          — remove all generated files

.PHONY: all lexer parser syntax ir test test-lexer test-parser clean

all: lexer parser ir

lexer:
	$(MAKE) -f Makefile.lexer all

parser:
	$(MAKE) -f Makefile.parser all

syntax: parser

ir:
	$(MAKE) -f Makefile.ir all

test: test-lexer test-parser

test-lexer: lexer
	$(MAKE) -f Makefile.lexer test

test-parser: parser
	$(MAKE) -f Makefile.parser test

clean:
	$(MAKE) -f Makefile.lexer clean
	$(MAKE) -f Makefile.parser clean
	$(MAKE) -f Makefile.ir clean
	-rm -rf out/ 2>/dev/null || (rd /S /Q out 2>NUL) || echo Cleaned
