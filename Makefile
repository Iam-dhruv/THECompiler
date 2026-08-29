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

.PHONY: all clean

all: $(LEXER) $(PARSER)

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
	cd $(SRC_DIR) && $(BISON) -d -o parser.tab.c parser.y

# ── Step 2: Run Flex on the Bison-driving lexer spec ─────────────────────────
#           (a separate file from src/lexer.l — different token codes, no
#            main() of its own, feeds tokens to the Bison parser instead)
$(SRC_DIR)/lex.yy.parser.c: $(SRC_DIR)/parser_lexer.l $(SRC_DIR)/parser.tab.h $(SRC_DIR)/common.h
	cd $(SRC_DIR) && $(FLEX) -o lex.yy.parser.c parser_lexer.l

# ── Step 3: Compile + link into syntax_analyzer (placed in project root) ───
$(PARSER): $(SRC_DIR)/parser.tab.c $(SRC_DIR)/lex.yy.parser.c
	$(CC) $(CFLAGS) $(SRC_DIR)/parser.tab.c $(SRC_DIR)/lex.yy.parser.c -o $(PARSER)

# ═══════════════════════════════ Cleanup ════════════════════════════════════

clean:
	rm -f $(SRC_DIR)/lex.yy.c
	rm -f $(SRC_DIR)/parser.tab.c $(SRC_DIR)/parser.tab.h $(SRC_DIR)/lex.yy.parser.c
	rm -f $(SRC_DIR)/parser.output
	rm -f $(LEXER) $(LEXER).exe $(PARSER) $(PARSER).exe
	rm -rf out/
