/* Digits immediately followed by identifier characters. A real C lexer
   scans these as ONE "preprocessing number" (C11 6.4.8) and then rejects
   it, rather than silently splitting "123abc" into 123 + abc. */
int   a = 123abc;      /* stray suffix on an integer          */
int   b = 0x;          /* hex prefix with no digits           */
int   c = 0xGG;        /* non-hex digits after 0x             */
int   d = 1_000;       /* '_' is an identifier char, not a separator */
float e = 1e5e5;       /* second exponent is a stray suffix   */
int   f = 0b101;       /* GNU binary literals are unsupported */
float g = 0x1p-3;      /* C99 hex floats are unsupported      */
