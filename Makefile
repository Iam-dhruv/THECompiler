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

LEXER   = lexer_app

.PHONY: all clean

all: $(LEXER)

$(SRC_DIR)/lex.yy.c: $(SRC_DIR)/lexer.l $(SRC_DIR)/tokens.h $(SRC_DIR)/symbol_table.h
	cd $(SRC_DIR) && $(FLEX) lexer.l

$(LEXER): $(SRC_DIR)/lex.yy.c
	$(CC) $(CFLAGS) $(SRC_DIR)/lex.yy.c -o $(LEXER)

clean:
	rm -f $(SRC_DIR)/lex.yy.c
	rm -f $(LEXER) $(LEXER).exe
	rm -rf out/
