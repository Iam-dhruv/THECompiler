# ─────────────────────────────────────────────────────────────────────────────
# Makefile — Compiler Design Lexer
#
# Usage:
#   make          — build lexer_app[.exe] in project root
#   make clean    — remove generated files and out/ directory
# ─────────────────────────────────────────────────────────────────────────────

CC      = g++
CFLAGS  = -std=c++17 -Wno-register
FLEX    = flex
SRC_DIR = src

# On Windows the binary gets a .exe extension automatically; on Linux/macOS it
# stays as lexer_app.  Both are handled by a single target name.
LEXER   = lexer_app

.PHONY: all clean

all: $(LEXER)

# ── Step 1: Run Flex on the grammar file to produce lex.yy.c ─────────────────
$(SRC_DIR)/lex.yy.c: $(SRC_DIR)/lexer.l $(SRC_DIR)/tokens.h $(SRC_DIR)/symbol_table.h
	cd $(SRC_DIR) && $(FLEX) lexer.l

# ── Step 2: Compile lex.yy.c → lexer_app (placed in project root) ────────────
$(LEXER): $(SRC_DIR)/lex.yy.c
	$(CC) $(CFLAGS) $(SRC_DIR)/lex.yy.c -o $(LEXER)

# ── Cleanup ───────────────────────────────────────────────────────────────────
clean:
	rm -f $(SRC_DIR)/lex.yy.c
	rm -f $(LEXER) $(LEXER).exe
	rm -rf out/
