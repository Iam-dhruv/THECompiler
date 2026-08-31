# ─────────────────────────────────────────────────────────────────────────────
# Makefile — THECompiler: Lexical Analyzer (Assignment 1) +
#                          Syntax Analyzer (Assignment 2)
#
# Usage:
#   make          — build both lexer_app[.exe] and syntax_analyzer[.exe]
#   make clean    — remove all generated files and the out/ directory
# ─────────────────────────────────────────────────────────────────────────────

CC       = g++
CFLAGS   = -std=c++17 -Wno-register
BISON    = bison
FLEX     = flex
SRC_DIR  = src

# On Windows the binaries get a .exe extension automatically; on Linux/macOS
# they stay without an extension. Both are handled by a single target name.
LEXER    = lexer_app
PARSER   = syntax_analyzer

.PHONY: all clean lexer parser syntax test

all: $(LEXER) $(PARSER)

lexer: $(LEXER)

parser: $(PARSER)

syntax: $(PARSER)

test: $(PARSER)
	bash ./run.sh || powershell -ExecutionPolicy Bypass -File ./run_tests.ps1

# ═══════════════════════ Assignment 1 — Lexical Analyzer ═══════════════════

# ── Step 1: Run Flex on the lexer spec to produce lex.yy.c ──────────────────
$(SRC_DIR)/lex.yy.c: $(SRC_DIR)/lexer.l $(SRC_DIR)/tokens.h $(SRC_DIR)/symbol_table.h
	cd $(SRC_DIR) && $(FLEX) lexer.l

# ── Step 2: Compile lex.yy.c → lexer_app (placed in project root) ───────────
$(LEXER): $(SRC_DIR)/lex.yy.c
	$(CC) $(CFLAGS) $(SRC_DIR)/lex.yy.c -o $(LEXER)

# ═══════════════════════ Assignment 2 — Syntax Analyzer ════════════════════

# ── Step 1: Run Bison on the grammar file to produce parser.tab.c/.h ────────
$(SRC_DIR)/parser.tab.c $(SRC_DIR)/parser.tab.h: $(SRC_DIR)/parser.y
	cd $(SRC_DIR) && (set BISON_PKGDATADIR=C:/PROGRA~2/GnuWin32/share/bison& set M4=C:/PROGRA~2/GnuWin32/bin/m4.exe& $(BISON) -d -o parser.tab.c parser.y) || $(BISON) -d -o parser.tab.c parser.y

# ── Step 2: Run Flex on the Bison-driving lexer spec ─────────────────────────
$(SRC_DIR)/lex.yy.parser.c: $(SRC_DIR)/parser_lexer.l $(SRC_DIR)/parser.tab.h $(SRC_DIR)/common.h
	cd $(SRC_DIR) && $(FLEX) parser_lexer.l && (move /Y lex.yy.c lex.yy.parser.c 2>NUL || mv -f lex.yy.c lex.yy.parser.c)

# ── Step 3: Compile + link into syntax_analyzer (placed in project root) ───
$(PARSER): $(SRC_DIR)/parser.tab.c $(SRC_DIR)/lex.yy.parser.c
	$(CC) $(CFLAGS) $(SRC_DIR)/parser.tab.c $(SRC_DIR)/lex.yy.parser.c -o $(PARSER)

# ═══════════════════════════════ Cleanup ════════════════════════════════════

clean:
	-rm -f $(SRC_DIR)/lex.yy.c $(SRC_DIR)/lex.yy.*.c $(SRC_DIR)/parser.tab.c $(SRC_DIR)/parser.tab.h $(SRC_DIR)/lex.yy.parser.c $(SRC_DIR)/parser.output $(SRC_DIR)/parser $(LEXER) $(LEXER).exe $(PARSER) $(PARSER).exe *.o $(SRC_DIR)/*.o 2>/dev/null || (del /Q /F $(SRC_DIR)\lex.yy.c $(SRC_DIR)\parser.tab.c $(SRC_DIR)\parser.tab.h $(SRC_DIR)\lex.yy.parser.c $(SRC_DIR)\parser.output $(SRC_DIR)\parser $(LEXER).exe $(PARSER).exe *.o 2>NUL) || echo Cleaned
	-rm -rf out/ 2>/dev/null || (rd /S /Q out 2>NUL) || echo Cleaned
